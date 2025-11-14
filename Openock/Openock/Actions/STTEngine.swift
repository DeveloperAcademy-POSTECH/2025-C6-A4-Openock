//
//  STTEngine.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

/*
 STTEngine
 
 Abstract:
 Integration class that combines AudioCaptureManager, AudioIOManager, and STTTranscriberManager
 to provide complete system-wide audio capture and speech-to-text functionality.
 */

import Foundation
import AVFoundation
import CoreAudio
import Combine

@available(macOS 15.0, *)
class STTEngine: NSObject, ObservableObject {
  
  // MARK: - Published Properties (UI State)

  @Published var transcript = ""
  @Published var isRecording = false
  @Published var isPaused = false
  @Published var errorMessage: String?
  @Published var audioLevel: Float = 0.0
  @Published var isReceivingAudio = false
  @Published var isWhistleDetected = false  // 휘슬 감지 상태
  @Published var whistleProbability: Float = 0.0  // 휘슬 확률 (디버깅용)
  @Published var audioEnergy: Float = 0.0  // 오디오 에너지 (디버깅용)
  @Published var dominantFrequency: Float = 0.0  // 주요 주파수 (디버깅용)
  @Published var stage1Probability: Float = 0.0  // 1단계 확률 (디버깅용)
  @Published var stage2Probability: Float = 0.0  // 2단계 확률 (디버깅용)

  // MARK: - Manager Components

  private let captureManager = AudioCaptureManager()
  private let ioManager = AudioIOManager()
  private let transcriberManager = STTTranscriberManager()
  private let whistleDetector = WhistleDetector()  // 휘슬 감지기
  
  private var deviceID: AudioObjectID = kAudioObjectUnknown
  private var cancellables = Set<AnyCancellable>()
  private var bufferCallCount = 0

  // MARK: - 텍스트 자동 정리 (5분 분량 유지)
  private let maxTextLength: Int = 1500  // 약 5분 분량의 텍스트

  // MARK: - Initialization
  
  override init() {
    super.init()
    print("🎙️ [STTEngine] Initialized")
    // Observe transcript changes from TranscriberManager
    observeTranscriber()
  }
  
  // MARK: - Public Interface
  
  /// Setup full system audio capture (captures ALL processes)
  func setupSystemCapture(completion: @escaping (Bool) -> Void) {
    print("🔧 [STTEngine] Setting up full system capture...")
    
    captureManager.setupFullSystemCapture { [weak self] deviceID in
      guard let self = self, let deviceID = deviceID else {
        DispatchQueue.main.async {
          self?.errorMessage = "오디오 캡처 설정 실패"
          completion(false)
        }
        return
      }
      
      self.deviceID = deviceID
      print("✅ [STTEngine] Full system capture ready! Device ID: \(deviceID)")
      
      DispatchQueue.main.async {
        completion(true)
      }
    }
  }
  
  /// Start recording and transcription
  func startRecording() {
    print("🎤 [STTEngine] Starting recording...")
    
    guard deviceID != kAudioObjectUnknown else {
      errorMessage = "디바이스가 설정되지 않았습니다. setupSystemCapture()를 먼저 호출하세요."
      print("❌ [STTEngine] No device set - call setupSystemCapture() first")
      return
    }
    
    // Start transcription task first
    Task {
      await transcriberManager.startTranscription()
    }
    
    // Give transcription task time to set up
    Task {
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
      
      // Start audio IO
      let success = self.ioManager.startIO(
        deviceID: self.deviceID,
        bufferCallback: { [weak self] buffer in
          self?.handleAudioBuffer(buffer)
        },
        levelCallback: { [weak self] level in
          self?.handleAudioLevel(level)
        }
      )
      
      if success {
        print("✅ [STTEngine] Recording started successfully")
        DispatchQueue.main.async {
          self.isRecording = true
          self.transcript = ""
          self.errorMessage = nil
        }
      } else {
        self.errorMessage = "오디오 IO를 시작할 수 없습니다"
        print("❌ [STTEngine] Failed to start audio IO")
      }
    }
  }
  
  /// Pause recording (audio still captured but not transcribed)
  func pauseRecording() {
    print("⏸ [STTEngine] Pausing recording...")
    ioManager.isPaused = true
    DispatchQueue.main.async {
      self.isPaused = true
    }
  }
  
  /// Resume recording
  func resumeRecording() {
    print("▶️ [STTEngine] Resuming recording...")
    ioManager.isPaused = false
    DispatchQueue.main.async {
      self.isPaused = false
    }
  }
  
  /// Stop recording and transcription
  func stopRecording() {
    print("🛑 [STTEngine] Stopping recording...")
    
    ioManager.stopIO()
    transcriberManager.stopTranscription()
    
    DispatchQueue.main.async {
      self.isRecording = false
      self.isPaused = false
    }
    
    print("✅ [STTEngine] Recording stopped")
  }
  
  /// Clear transcript text
  func clearTranscript() {
    transcriberManager.clearTranscript()
    DispatchQueue.main.async {
      self.transcript = ""
      self.errorMessage = nil
    }
  }

  // === ✅ 추가: 파이프라인 연동용 경량 API =============================

  /// 파이프라인이 IO를 담당할 때, 전사 파이프라인만 시작
  @MainActor
  func startTranscriptionOnly() async {
    print("🎙️ [STTEngine] Starting transcription only...")
    await transcriberManager.startTranscription()
    print("✅ [STTEngine] Transcription started, transcriberManager.isTranscribing: \(transcriberManager.isTranscribing)")
  }

  /// 파이프라인이 IO를 담당할 때, 전사 파이프라인만 중지
  func stopTranscriptionOnly() {
    print("🛑 [STTEngine] Stopping transcription only...")
    transcriberManager.stopTranscription()
    print("✅ [STTEngine] Transcription stopped, isTranscribing: \(transcriberManager.isTranscribing)")
  }

  /// 파이프라인에서 받은 PCM을 그대로 STT로 전달
  func feed(buffer: AVAudioPCMBuffer) {
    transcriberManager.processAudio(buffer: buffer)
  }

  // ===================================================================
  
  // MARK: - Private Methods
  
  /// Handle audio buffer from AudioIOManager
  private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    // Send buffer to transcriber
    transcriberManager.processAudio(buffer: buffer)

    // Update receiving audio status and check whistle (occasionally)
    bufferCallCount += 1

    // Whistle detection (10번에 한 번씩 체크 - 매우 빠른 반응)
    if bufferCallCount % 10 == 0 {
      // 백그라운드 스레드에서 실행하여 메인 오디오 처리에 영향 없도록
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        let whistleDetected = self.whistleDetector.detectWhistle(from: buffer)

        // UI에 디버깅 정보 업데이트
        DispatchQueue.main.async {
          self.whistleProbability = self.whistleDetector.lastWhistleProbability
          self.audioEnergy = self.whistleDetector.lastRMSEnergy
          self.dominantFrequency = self.whistleDetector.lastDominantFrequency
          self.stage1Probability = self.whistleDetector.lastStage1Probability
          self.stage2Probability = self.whistleDetector.lastStage2Probability
        }

        if whistleDetected {
          DispatchQueue.main.async {
            self.isWhistleDetected = true
            print("🎵 [STTEngine] Whistle detected!")
          }

          // 3초 후 자동으로 아이콘 사라지게
          DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.isWhistleDetected = false
          }
        }
      }
    }

    if bufferCallCount % 30 == 1 {
      DispatchQueue.main.async {
        self.isReceivingAudio = true
      }
    }
  }
  
  /// Handle audio level updates from AudioIOManager
  private func handleAudioLevel(_ level: Float) {
    DispatchQueue.main.async {
      self.audioLevel = level
    }
  }
  
  // MARK: - Observation
  private func observeTranscriber() {
    // Observe transcript changes
    transcriberManager.$transcript
      .sink { [weak self] newTranscript in
        guard let self = self else { return }
        DispatchQueue.main.async {
          self.transcript = self.formatTranscript(newTranscript)
          self.cleanupOldTextIfNeeded()
        }
      }
      .store(in: &cancellables)

    // Observe error messages
    transcriberManager.$errorMessage
      .sink { [weak self] newError in
        DispatchQueue.main.async {
          self?.errorMessage = newError
        }
      }
      .store(in: &cancellables)
  }
  
  // MARK: - Cleanup
  
  deinit {
    print("🗑️ [STTEngine] Deallocating...")
    stopRecording()
  }
  
  // MARK: - STT Post-processing
  private func formatTranscript(_ text: String) -> String {
    guard !text.isEmpty else { return "" }

    // 문장부호(., ?, !, ~, …) 뒤에서 줄바꿈
//    let formatted = text.replacingOccurrences(
//      of: "([.!?~…])\\s*",
//      with: "$1\n",
//      options: .regularExpression
//    )
//    return formatted.trimmingCharacters(in: .whitespacesAndNewlines)

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - 텍스트 자동 정리
  private func cleanupOldTextIfNeeded() {
    // 텍스트가 maxTextLength를 초과하면 앞부분 삭제
    guard transcript.count > maxTextLength else { return }

    // 초과된 길이 + 여유분(200자) 계산
    let excessLength = transcript.count - maxTextLength + 200
    let startIndex = transcript.startIndex

    // 삭제할 기본 위치
    guard excessLength < transcript.count else {
      transcript = String(transcript.suffix(maxTextLength))
      return
    }

    var cutIndex = transcript.index(startIndex, offsetBy: excessLength, limitedBy: transcript.endIndex) ?? transcript.endIndex

    // 문장 부호(. ! ? 또는 공백) 뒤에서 자르기
    let sentenceEnders: Set<Character> = [".", "!", "?", " "]
    while cutIndex < transcript.endIndex {
      if sentenceEnders.contains(transcript[cutIndex]) {
        cutIndex = transcript.index(after: cutIndex)
        break
      }
      cutIndex = transcript.index(after: cutIndex)
    }

    // 텍스트 업데이트
    transcript = String(transcript[cutIndex...])
  }
}
