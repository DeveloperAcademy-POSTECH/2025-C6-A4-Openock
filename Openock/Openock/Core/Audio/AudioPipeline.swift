//
//  AudioPipeline.swift
//  Openock
//
//  Created by YONGWON SEO on 11/5/25.
//

import Foundation
import AVFoundation
import Combine

final class AudioPipeline: ObservableObject {
    // UI 상태
    @Published var yamStatus: String = "YAMNet: idle"
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false

    // 👉 오버레이 트리거 전달용
    @Published var yamCue: YamCue?

    // 내부 구성요소
    private let capture = AudioCaptureManager()
    private let io = AudioIOManager()
    private let yamRunner = YAMNetRunner()

    // ✅ 팀 공용 STT 엔진 사용 (분석 파이프라인만 사용)
    @available(macOS 15.0, *)
    private let sttEngine = STTEngine()

    private var bag = Set<AnyCancellable>()

    init() {
        // YAM 상태 반영
        yamRunner.$statusText
            .receive(on: DispatchQueue.main)
            .assign(to: &$yamStatus)

        // ✅ 러너 cue → 파이프라인으로 중계
        yamRunner.$cue
            .receive(on: DispatchQueue.main)
            .assign(to: &$yamCue)

        // ✅ STTEngine의 transcript 반영
        if #available(macOS 15.0, *) {
            sttEngine.$transcript
                .receive(on: DispatchQueue.main)
                .assign(to: &$transcript)
        }
    }

    // 캡처 + IO 시작
    func setupAndStart() {
        capture.setupFullSystemCapture { [weak self] deviceID in
            guard let self, let devID = deviceID else { return }

            // ✅ STTEngine: 캡처/IO는 쓰지 않고, 분석 파이프라인만 켜기
            if #available(macOS 15.0, *) {
                Task { @MainActor in
                    await self.sttEngine.startTranscriptionOnly()
                }
            }

            let ok = self.io.startIO(
                deviceID: devID,
                bufferCallback: { [weak self] pcm in
                    guard let self else { return }
                    // 1) YAMNet (러너가 내부에서 16k 변환)
                    self.yamRunner.ingest(pcm)
                    // 2) STT (원본 PCM 그대로 전달)
                    if #available(macOS 15.0, *) {
                        self.sttEngine.feed(buffer: pcm)
                    }
                },
                levelCallback: { _ in }
            )

            DispatchQueue.main.async {
                self.isRecording = ok
                self.isPaused = false
            }
        }
    }

    func startRecording() { // 뷰에서 호출
        setupAndStart()
    }

    func stop() {
        io.stopIO()
        capture.cleanup()
        if #available(macOS 15.0, *) {
            sttEngine.stopTranscriptionOnly()   // ✅ 전사 파이프라인만 정리
        }
        isRecording = false
        isPaused = false
    }

    func pauseRecording() {
        io.isPaused = true
        isPaused = true
    }

    func resumeRecording() {
        io.isPaused = false
        isPaused = false
    }
}
