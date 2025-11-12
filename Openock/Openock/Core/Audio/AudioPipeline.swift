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
  // MARK: - UI 상태
  @Published var yamStatus: String = "YAMNet: idle"
  @Published var transcript: String = ""
  @Published var isRecording: Bool = false
  @Published var isPaused: Bool = false

  // Whistle 디버그
  @Published var isWhistleDetected: Bool = false
  @Published var whistleProbability: Float = 0.0
  @Published var audioEnergy: Float = 0.0
  @Published var dominantFrequency: Float = 0.0
  @Published var stage1Probability: Float = 0.0
  @Published var stage2Probability: Float = 0.0

  // 라우드니스/스타일
  @Published var loudnessDB: Double = 0
  @Published var fxStyle: SubtitleStyle = .neutral

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
  private var currentBackgroundKey: String = "화이트"

  // MARK: - 기능 토글 (OnOffManager가 갱신)
  private(set) var enableSizeFX: Bool = true
  private(set) var enableYamReactions: Bool = true
  private(set) var enableWhistle: Bool = true

  // MARK: - Combine
  private var bag = Set<AnyCancellable>()
  private var settingsBag = Set<AnyCancellable>()

  // MARK: - Init
  init() {
    // YAM 상태
    yamRunner.$statusText
      .receive(on: DispatchQueue.main)
      .assign(to: &$yamStatus)

    // STT 자막
    if #available(macOS 15.0, *) {
      sttEngine.$transcript
        .receive(on: DispatchQueue.main)
        .assign(to: &$transcript)
    }

    whistleManager = WhistleIndicatorWindowManager(pipeline: self)

    // dB → FX 갱신 (토글 반영)
    loudness.$dB
      .receive(on: DispatchQueue.main)
      .sink { [weak self] db in
        guard let self else { return }
        self.loudnessDB = db
        if self.enableSizeFX {
          self.fxEngine.update(
            dB: db,
            baseFontSize: self.currentFontSize,
            baseTextColor: self.currentTextColor,
            selectedBackground: self.currentBackgroundKey
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
    currentBackgroundKey = normalizeBackgroundKey(settings.selectedBackground)

    // 글꼴 크기 변경 → 상대 확대 재계산
    settings.$fontSize
      .receive(on: DispatchQueue.main)
      .sink { [weak self] size in
        guard let self else { return }
        self.currentFontSize = size
        self.refreshFXStyle()
      }
      .store(in: &settingsBag)

    // 배경 프리셋 변경 → 텍스트 색/키 재스냅샷
    settings.$selectedBackground
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak settings] bg in
        guard let self, let settings else { return }
        self.currentBackgroundKey = self.normalizeBackgroundKey(bg)
        self.currentTextColor = settings.textColor
        self.refreshFXStyle()
      }
      .store(in: &settingsBag)

    // 커스텀 컬러 저장 → 텍스트 색 재스냅샷
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

  private func refreshFXStyle() {
    guard enableSizeFX else { fxStyle = .neutral; return }
    fxEngine.update(
      dB: loudnessDB,
      baseFontSize: currentFontSize,
      baseTextColor: currentTextColor,
      selectedBackground: currentBackgroundKey
    )
  }

  private func normalizeBackgroundKey(_ raw: String) -> String {
    let lower = raw.lowercased()
    if lower.contains("custom") || lower.contains("커스텀") { return "커스텀" }
    if lower.contains("black")  || lower.contains("블랙")   { return "블랙" }
    if lower.contains("white")  || lower.contains("화이트") { return "화이트" }
    return "화이트"
  }

  // MARK: - 캡처 + IO
  func setupAndStart() {
    capture.setupFullSystemCapture { [weak self] deviceID in
      guard let self, let devID = deviceID else { return }

      // STT 파이프라인은 항상 켬 (자막 기본 동작 유지)
      if #available(macOS 15.0, *) {
        Task { @MainActor in
          await self.sttEngine.startTranscriptionOnly()
        }
      }

      let ok = self.io.startIO(
        deviceID: devID,
        bufferCallback: { [weak self] pcm in
          guard let self else { return }

          // STT: 항상 동작
          if #available(macOS 15.0, *) {
            self.sttEngine.feed(buffer: pcm)
          }

          // YAM 반응: 토글 시에만
          if self.enableYamReactions {
            self.yamRunner.ingest(pcm)
          }

          // Whistle: 토글 시에만
          if self.enableWhistle, #available(macOS 15.0, *) {
            self.handleWhistleDetection(buffer: pcm)
          }

          // 라우드니스: 항상 측정 (적용은 토글이 결정)
          self.loudness.ingest(pcm)
        },
        levelCallback: { _ in }
      )

      self.isRecording = ok
      self.isPaused = false
      if !self.enableYamReactions {
        self.yamStatus = "YAMNet: disabled"
      }
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
    io.isPaused = true
    isPaused = true
  }

  func resumeRecording() {
    if #available(macOS 15.0, *) {
      sttEngine.stopTranscriptionOnly()
      sttEngine.clearTranscript()
      Task { @MainActor in
        await sttEngine.startTranscriptionOnly()
      }
    }
    io.isPaused = false
    isPaused = false
    transcript = ""
  }

  // MARK: - Whistle (Sendable 경고 회피: 딥카피 후 백그라운드 처리)
  @available(macOS 15.0, *)
  private func handleWhistleDetection(buffer: AVAudioPCMBuffer) {
    // 백그라운드로 넘기기 전에 동일 스레드에서 안전하게 복제
    guard let copied = Self.deepCopyPCMBuffer(buffer) else { return }

    // 백그라운드 큐 클로저는 @Sendable 취급되므로 non-Sendable 직접 캡처 회피
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

  // AVAudioPCMBuffer 안전 복제
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
          // ✅ AudioBufferList 포인터 안전 변환
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
