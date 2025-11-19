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
import AVFoundation   // 🔊 버퍼/포맷용으로만 사용 (권한 X)
import CoreAudio
import Combine
import Speech         // ✅ 음성 인식 권한만 체크

@available(macOS 15.0, *)
class STTEngine: NSObject, ObservableObject {

  // MARK: - Published Properties (UI State)

  @Published var transcript = ""
  @Published var isRecording = false
  @Published var isPaused = false
  @Published var errorMessage: String?
  @Published var audioLevel: Float = 0.0
  @Published var isReceivingAudio = false
  @Published var isWhistleDetected = false
  @Published var whistleProbability: Float = 0.0
  @Published var audioEnergy: Float = 0.0
  @Published var dominantFrequency: Float = 0.0
  @Published var stage1Probability: Float = 0.0
  @Published var stage2Probability: Float = 0.0

  // MARK: - Manager Components

  private let captureManager = AudioCaptureManager()
  private let ioManager = AudioIOManager()
  private let transcriberManager = STTTranscriberManager()
  private let whistleDetector = WhistleDetector()

  private var deviceID: AudioObjectID = kAudioObjectUnknown
  private var cancellables = Set<AnyCancellable>()
  private var bufferCallCount = 0

  // MARK: - 텍스트 자동 정리
  private let maxTextLength: Int = 500

  // MARK: - Initialization

  override init() {
    super.init()
    print("🎙️ [STTEngine] Initialized")
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

    // ✅ 실제 녹음 시작 전에 "음성 인식 권한"만 재확인
    ensureSpeechPermission { [weak self] granted in
      guard let self = self else { return }

      guard granted else {
        DispatchQueue.main.async {
          self.errorMessage = "권한이 없어 자막을 시작할 수 없습니다.\n음성 인식 권한을 확인해주세요."
          self.isRecording = false
          self.isPaused = false
        }
        print("❌ [STTEngine] Speech permission not granted – aborting startRecording()")
        return
      }

      // 🔽 기존 로직 그대로
      Task {
        await self.transcriberManager.startTranscription()
      }

      Task {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

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
          DispatchQueue.main.async {
            self.errorMessage = "오디오 IO를 시작할 수 없습니다"
          }
          print("❌ [STTEngine] Failed to start audio IO")
        }
      }
    }
  }

  func pauseRecording() {
    print("⏸ [STTEngine] Pausing recording...")
    ioManager.isPaused = true
    DispatchQueue.main.async { self.isPaused = true }
  }

  func resumeRecording() {
    print("▶️ [STTEngine] Resuming recording...")
    ioManager.isPaused = false
    DispatchQueue.main.async { self.isPaused = false }
  }

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

  func clearTranscript() {
    transcriberManager.clearTranscript()
    DispatchQueue.main.async {
      self.transcript = ""
      self.errorMessage = nil
    }
  }

  // === 파이프라인 연동용 경량 API =============================

  @MainActor
  func startTranscriptionOnly() async {
    print("🎙️ [STTEngine] Starting transcription only...")

    let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      ensureSpeechPermission { ok in
        continuation.resume(returning: ok)
      }
    }

    guard granted else {
      self.errorMessage = "권한이 없어 자막을 시작할 수 없습니다.\n음성 인식 권한을 확인해주세요."
      print("❌ [STTEngine] Speech permission not granted – aborting startTranscriptionOnly()")
      return
    }

    await transcriberManager.startTranscription()
    print("✅ [STTEngine] Transcription started, transcriberManager.isTranscribing: \(transcriberManager.isTranscribing)")
  }

  func stopTranscriptionOnly() {
    print("🛑 [STTEngine] Stopping transcription only...")
    transcriberManager.stopTranscription()
    print("✅ [STTEngine] Transcription stopped, isTranscribing: \(transcriberManager.isTranscribing)")
  }

  func feed(buffer: AVAudioPCMBuffer) {
    transcriberManager.processAudio(buffer: buffer)
  }

  // ===================================================================

  // MARK: - 권한 체크 유틸 (Speech 만)

  private func ensureSpeechPermission(completion: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { status in
      let ok: Bool
      switch status {
      case .authorized:
        ok = true
      default:
        ok = false
      }
      if !ok {
        print("⚠️ [STTEngine] Speech permission denied or not authorized: \(status.rawValue)")
      }
      DispatchQueue.main.async {
        completion(ok)
      }
    }
  }

  // MARK: - Private Methods

  private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    transcriberManager.processAudio(buffer: buffer)

    bufferCallCount += 1

    if bufferCallCount % 10 == 0 {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        let whistleDetected = self.whistleDetector.detectWhistle(from: buffer)

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
          DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.isWhistleDetected = false
          }
        }
      }
    }

    if bufferCallCount % 30 == 1 {
      DispatchQueue.main.async { self.isReceivingAudio = true }
    }
  }

  private func handleAudioLevel(_ level: Float) {
    DispatchQueue.main.async { self.audioLevel = level }
  }

  // MARK: - Observation

  private func observeTranscriber() {
    transcriberManager.$transcript
      .sink { [weak self] newTranscript in
        guard let self = self else { return }
        DispatchQueue.main.async {
          self.transcript = self.formatTranscript(newTranscript)
          self.cleanupOldTextIfNeeded()
        }
      }
      .store(in: &cancellables)

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
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func cleanupOldTextIfNeeded() {
    guard transcript.count > maxTextLength else { return }

    let excessLength = transcript.count - maxTextLength + 200
    let startIndex = transcript.startIndex

    guard excessLength < transcript.count else {
      transcript = String(transcript.suffix(maxTextLength))
      return
    }

    var cutIndex = transcript.index(startIndex, offsetBy: excessLength, limitedBy: transcript.endIndex) ?? transcript.endIndex

    let sentenceEnders: Set<Character> = [".", "!", "?", " "]
    while cutIndex < transcript.endIndex {
      if sentenceEnders.contains(transcript[cutIndex]) {
        cutIndex = transcript.index(after: cutIndex)
        break
      }
      cutIndex = transcript.index(after: cutIndex)
    }

    transcript = String(transcript[cutIndex...])
  }
}
