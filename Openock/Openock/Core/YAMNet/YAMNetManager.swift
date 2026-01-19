//
//  YAMNetManager.swift
//  Openock
//
//  Created by YONGWON SEO on 11/05/25.
//

import Foundation
import AVFoundation
import Combine

final class YAMNetManager: ObservableObject {
  // UI 바인딩용
  @Published var statusText: String = "YAMNet: idle"
  @Published var topLabel: String = "idle"
  @Published var topScore: Float = 0
  @Published var topK: [(String, Float)] = []
  @Published var isRecording: Bool = false
  @Published var isPaused: Bool = false

  // 의존성
  private let capture = AudioCaptureManager()
  private let io = AudioIOManager()
  private let yamnet = YAMNetLite()

  // STT에게도 버퍼를 전달하기 위한 약한 참조 (브릿지는 아니고, 단순 전달자)
  weak var stt: STTTranscriberManager?

  // 분류 호출 스로틀링
  private var bufferCount = 0
  private let classifyEveryN = 5   // 대략 100~200ms마다 1회 추론(환경에 맞춰 조정)

  // MARK: - Control
  func start() {
    guard !isRecording else { return }
    statusText = "YAMNet: starting…"

    capture.setupFullSystemCapture { [weak self] deviceID in
      guard let self = self, let deviceID else {
        DispatchQueue.main.async { self?.statusText = "YAMNet: failed to setup capture" }
        return
      }

      let ok = self.io.startIO(
        deviceID: deviceID,
        bufferCallback: { [weak self] buf in self?.handleBuffer(buf) },
        levelCallback: { _ in }
      )

      DispatchQueue.main.async {
        if ok {
          self.isRecording = true
          self.isPaused = false
          self.statusText = "YAMNet: running"
        } else {
          self.statusText = "YAMNet: failed to start IO"
        }
      }
    }
  }

  func stop() {
    guard isRecording else { return }
    io.stopIO()
    capture.cleanup()
    isRecording = false
    isPaused = false
    statusText = "YAMNet: stopped"
  }

  func pause() {
    guard isRecording, !isPaused else { return }
    io.isPaused = true
    isPaused = true
    statusText = "YAMNet: paused"
  }

  func resume() {
    guard isRecording, isPaused else { return }
    io.isPaused = false
    isPaused = false
    statusText = "YAMNet: running"
  }

  // MARK: - Buffer
  private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
    // 1) STT 쪽에도 동일 PCM을 전달 (필요할 때만)
    stt?.processAudio(buffer: buffer)

    // 2) YAMNet 추론 (스로틀링)
    bufferCount &+= 1
    if bufferCount % classifyEveryN != 0 { return }

    let result = yamnet.classify(buffer: buffer, topK: 3)
    if let best = result.topK.first {
      DispatchQueue.main.async {
        self.topLabel = best.label
        self.topScore = best.score
        self.topK = result.topK
        self.statusText = "YAMNet: \(best.label) (\(String(format: "%.2f", best.score)))"
      }
    } else {
      DispatchQueue.main.async {
        self.topLabel = "idle"
        self.topScore = 0
        self.topK = []
        self.statusText = "YAMNet: idle"
      }
    }
  }

  deinit {
    stop()
  }
}
