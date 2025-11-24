//
//  AudioPipeline.swift
//  Openock
//
//  Created by YONGWON SEO on 11/5/25.
//

import Foundation
@preconcurrency import AVFoundation   // AVFAudio/AVFoundation의 Sendable 경고 억제
@preconcurrency import AVFAudio
import Combine
import SwiftUI

@MainActor
final class AudioPipeline: ObservableObject {
  // MARK: - 공개 UI 상태
  @Published var yamStatus: String = "YAMNet: idle"
  @Published var transcript: String = ""
  @Published var isRecording: Bool = false
  @Published var isPaused: Bool = false

  // 라우드니스/스타일
  @Published var loudnessDB: Double = 0
  @Published var fxStyle: SubtitleStyle = .neutral

  // (HEAD 의도) YAMNet 큐 신호
  @Published var yamCue: YamCue?

  // (feat/#34 의도) Whistle 디버그
  @Published var isWhistleDetected: Bool = false
  @Published var whistleProbability: Float = 0.0
  @Published var audioEnergy: Float = 0.0
  @Published var dominantFrequency: Float = 0.0
  @Published var stage1Probability: Float = 0.0
  @Published var stage2Probability: Float = 0.0

  // MARK: - 내부 구성요소
  private let capture = AudioCaptureManager()
  private let io = AudioIOManager()
  private let yamRunner = YAMNetRunner()
  private let loudness = LoudnessMeter()
  private let fxEngine = SubtitleFXEngine()

  @available(macOS 15.0, *)
  private let whistleDetector = WhistleDetector()
  @available(macOS 15.0, *)
  private let sttEngine = STTEngine()

  private var whistleManager: WhistleIndicatorWindowManager?

  // MARK: - Settings 스냅샷
  private var settings: SettingsManager?
  private var currentFontSize: CGFloat = 24
  private var currentTextColor: Color = .black

  // MARK: - 기능 토글 (OnOffManager가 갱신)
  private(set) var enableSizeFX: Bool = true
  private(set) var enableYamReactions: Bool = true
  private(set) var enableWhistle: Bool = true

  // MARK: - Combine
  private var bag = Set<AnyCancellable>()
  private var settingsBag = Set<AnyCancellable>()

  // MARK: - Resume Task 관리
  private var resumeTask: Task<Void, Never>?

  // MARK: - Init
  init() {
    // YAM 상태 텍스트
    yamRunner.$statusText
      .receive(on: DispatchQueue.main)
      .assign(to: &$yamStatus)

    // (HEAD 의도) YAM cue 신호 구독
    yamRunner.$cue
      .receive(on: DispatchQueue.main)
      .assign(to: &$yamCue)

    // STT 자막
    if #available(macOS 15.0, *) {
      sttEngine.$transcript
        .receive(on: DispatchQueue.main)
        .assign(to: &$transcript)
    }

    whistleManager = WhistleIndicatorWindowManager(pipeline: self)

    // MARK: dB → FX 갱신 (토글 + 하이라이트 색 반영)
    loudness.$dB
      .receive(on: DispatchQueue.main)
      .sink { [weak self] db in
        guard let self else { return }
        self.loudnessDB = db

        if self.enableSizeFX {
          // SettingsManager에서 선택한 강조색 사용 (없으면 텍스트 색으로 fallback)
          let highlight = self.settings?.highlightColor ?? self.currentTextColor

          self.fxEngine.update(
            dB: db,
            baseFontSize: self.currentFontSize,
            baseTextColor: self.currentTextColor,
            highlightColor: highlight
          )
        } else {
          self.fxStyle = .neutral
        }
      }
      .store(in: &bag)

    // fxEngine → fxStyle (토글 방어)
    fxEngine.$style
      .receive(on: DispatchQueue.main)
      .sink { [weak self] style in
        guard let self else { return }
        self.fxStyle = self.enableSizeFX ? style : .neutral
      }
      .store(in: &bag)
  }

  // MARK: - Settings 바인딩
  func bindSettings(_ settings: SettingsManager) {
    self.settings = settings
    settingsBag.removeAll()

    // 초기 스냅샷
    currentFontSize = settings.fontSize
    currentTextColor = settings.textColor

    // 글꼴 크기 변경 → 상대 확대 재계산
    settings.$fontSize
      .receive(on: DispatchQueue.main)
      .sink { [weak self] size in
        guard let self else { return }
        self.currentFontSize = size
        self.refreshFXStyle()
      }
      .store(in: &settingsBag)

    // 배경 프리셋 변경 → 텍스트 색 재스냅샷
    settings.$selectedBackground
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak settings] _ in
        guard let self, let settings else { return }
        self.currentTextColor = settings.textColor
        self.refreshFXStyle()
      }
      .store(in: &settingsBag)

    // 커스텀 컬러 저장(색상 피커 등) → 텍스트 색 재스냅샷
    NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
      .sink { [weak self, weak settings] _ in
        guard let self, let settings else { return }
        self.currentTextColor = settings.textColor
        self.refreshFXStyle()
      }
      .store(in: &settingsBag)

    refreshFXStyle()
  }

  // MARK: - FX Style 재계산
  private func refreshFXStyle() {
    guard enableSizeFX else {
      fxStyle = .neutral
      return
    }
    let highlight = settings?.highlightColor ?? currentTextColor

    fxEngine.update(
      dB: loudnessDB,
      baseFontSize: currentFontSize,
      baseTextColor: currentTextColor,
      highlightColor: highlight
    )
  }

  // MARK: - 캡처 + IO
  func setupAndStart() {
    // 이미 녹음 중이면 무시
    if isRecording {
      print("ℹ️ [AudioPipeline] setupAndStart() called while already recording – ignored")
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.isRecording = true
      self.isPaused = false
    }

    capture.setupFullSystemCapture { [weak self] deviceID in
      guard let self = self else { return }
      guard let devID = deviceID else {
        print("❌ [AudioPipeline] setupFullSystemCapture failed")
        self.isRecording = false
        self.isPaused = false
        return
      }

      print("🎧 [AudioPipeline] Using aggregate deviceID: \(devID)")

      // 👉 STT 먼저 세팅하고, 끝난 뒤에 IO 시작
      if #available(macOS 15.0, *) {
        Task { @MainActor in
          print("🎙️ [AudioPipeline] Starting STT transcription-only pipeline...")
          await self.sttEngine.startTranscriptionOnly()

          // STT 쪽에서 트랜스크라이버/애널라이저 초기화할 시간 조금 줌
          // (예전 STTEngine에서도 0.1초 슬립 쓰던 패턴 그대로 연장)
          try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초

          self.startIOWithDevice(devID)
        }
      } else {
        // macOS 15 미만이면 STT 없이 바로 IO
        self.startIOWithDevice(devID)
      }
    }
  }

  // IO 시작 부분만 함수로 뺌 (중복 줄이려고)
  private func startIOWithDevice(_ devID: AudioObjectID) {
    let ok = self.io.startIO(
      deviceID: devID,
      bufferCallback: { [weak self] pcm in
        guard let self else { return }

        // STT: 항상 동작
        if #available(macOS 15.0, *) {
          self.sttEngine.feed(buffer: pcm)
        }

        // YAM 반응
        if self.enableYamReactions {
          self.yamRunner.ingest(pcm)
        }

        // Whistle (지금은 잠깐 꺼두는 걸 추천)
        if self.enableWhistle, #available(macOS 15.0, *) {
          self.handleWhistleDetection(buffer: pcm)
        }

        // 라우드니스
        self.loudness.ingest(pcm)
      },
      levelCallback: { _ in }
    )

    self.isRecording = ok
    self.isPaused = false

    if !ok {
      print("❌ [AudioPipeline] io.startIO failed")
    } else if !self.enableYamReactions {
      self.yamStatus = "YAMNet: disabled"
    }
  }

  // MARK: - Public controls
  func startRecording() { setupAndStart() }

  func stop() {
    io.stopIO()
    capture.cleanup()
    if #available(macOS 15.0, *) {
      sttEngine.stopTranscriptionOnly()
    }
    isRecording = false
    isPaused = false
  }

  func pauseRecording() {
    print("⏸ [AudioPipeline] Pausing recording...")

    // 진행 중인 resume task 취소
    if resumeTask != nil {
      print("🔴 [AudioPipeline] Cancelling active resume task")
      resumeTask?.cancel()
      resumeTask = nil
    }

    io.isPaused = true
    isPaused = true
    print("✅ [AudioPipeline] Paused - io.isPaused: \(io.isPaused), isPaused: \(isPaused)")
  }

  func resumeRecording() {
    print("▶️ [AudioPipeline] Resuming recording...")
    print("📊 [AudioPipeline] Current state - io.isPaused: \(io.isPaused), isPaused: \(isPaused)")

    // 재생 버튼 누를 때 오디오 탭 갱신 (새로운 오디오 프로세스 감지)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.capture.refreshAudioTap()
    }

    // 이전 resume task 취소
    resumeTask?.cancel()

    if #available(macOS 15.0, *) {
      // STT 재시작 중에는 일시적으로 pause 상태 유지 (버퍼 무시)
      io.isPaused = true
      isPaused = true

      // STT 재시작을 비동기로 처리
      resumeTask = Task { @MainActor in
        print("🔄 [AudioPipeline] Task started - stopping STT...")

        // STT 중지 및 초기화
        self.sttEngine.stopTranscriptionOnly()
        self.sttEngine.clearTranscript()
        self.transcript = ""

        print("🔄 [AudioPipeline] Starting STT...")
        await self.sttEngine.startTranscriptionOnly()

        // Task가 취소되었는지 확인
        if Task.isCancelled {
          print("⚠️ [AudioPipeline] Resume task was cancelled after STT start")
          return
        }

        // Additional delay to ensure analyzers are fully ready
        print("⏳ [AudioPipeline] Waiting for analyzers to fully initialize...")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Task가 취소되었는지 다시 확인
        if Task.isCancelled {
          print("⚠️ [AudioPipeline] Resume task was cancelled during sleep")
          return
        }

        print("✅ [AudioPipeline] STT ready, unpausing IO...")
        // STT가 준비된 후에 오디오 재개
        self.io.isPaused = false
        self.isPaused = false
        print("✅ [AudioPipeline] Resumed - io.isPaused: \(self.io.isPaused), isPaused: \(self.isPaused)")
      }
    } else {
      // macOS 15.0 미만에서는 STT 없이 바로 재개
      io.isPaused = false
      isPaused = false
      transcript = ""
    }
  }

  // MARK: - Whistle (Sendable 경고 회피: 딥카피 후 백그라운드 처리)
  @available(macOS 15.0, *)
  private func handleWhistleDetection(buffer: AVAudioPCMBuffer) {
    guard let copied = Self.deepCopyPCMBuffer(buffer) else { return }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let detected = self.whistleDetector.detectWhistle(from: copied)

      DispatchQueue.main.async {
        self.whistleProbability = self.whistleDetector.lastWhistleProbability
        self.audioEnergy = self.whistleDetector.lastRMSEnergy
        self.dominantFrequency = self.whistleDetector.lastDominantFrequency
        self.stage1Probability = self.whistleDetector.lastStage1Probability
        self.stage2Probability = self.whistleDetector.lastStage2Probability
      }

      if detected {
        DispatchQueue.main.async { self.isWhistleDetected = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
          self.isWhistleDetected = false
        }
      }
    }
  }

  // MARK: - AVAudioPCMBuffer 안전 복제
  private static func deepCopyPCMBuffer(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    let format = src.format
    guard let dst = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: src.frameCapacity) else { return nil }
    dst.frameLength = src.frameLength

    let frames = Int(src.frameLength)
    let channels = Int(format.channelCount)

    switch format.commonFormat {
    case .pcmFormatFloat32:
      guard let s = src.floatChannelData, let d = dst.floatChannelData else { return nil }
      let bytes = frames * MemoryLayout<Float>.size
      for ch in 0..<channels { memcpy(d[ch], s[ch], bytes) }
    case .pcmFormatInt16:
      guard let s = src.int16ChannelData, let d = dst.int16ChannelData else { return nil }
      let bytes = frames * MemoryLayout<Int16>.size
      for ch in 0..<channels { memcpy(d[ch], s[ch], bytes) }
    case .pcmFormatInt32:
      guard let s = src.int32ChannelData, let d = dst.int32ChannelData else { return nil }
      let bytes = frames * MemoryLayout<Int32>.size
      for ch in 0..<channels { memcpy(d[ch], s[ch], bytes) }
    default:
      let srcList = unsafeBitCast(src.audioBufferList, to: UnsafeMutablePointer<AudioBufferList>.self)
      let sABL = UnsafeMutableAudioBufferListPointer(srcList)
      let dABL = UnsafeMutableAudioBufferListPointer(dst.mutableAudioBufferList)
      for i in 0..<sABL.count {
        let byteSize = Int(sABL[i].mDataByteSize)
        if byteSize > 0, let sp = sABL[i].mData, let dp = dABL[i].mData {
          memcpy(dp, sp, byteSize)
          dABL[i].mDataByteSize = sABL[i].mDataByteSize
        }
      }
    }
    return dst
  }

  // MARK: - On/Off 적용(API)
  func applySizeFXEnabled(_ on: Bool) {
    enableSizeFX = on
    if !on {
      fxStyle = .neutral
    } else {
      refreshFXStyle()
    }
  }

  func applyYamReactionsEnabled(_ on: Bool) {
    enableYamReactions = on
    yamStatus = on ? "YAMNet: idle" : "YAMNet: disabled"
  }

  func applyWhistleEnabled(_ on: Bool) {
    enableWhistle = on
    if !on {
      isWhistleDetected = false
      whistleProbability = 0
      stage1Probability = 0
      stage2Probability = 0
    }
  }
}
