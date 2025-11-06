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

    // 호루라기 감지 상태
    @Published var isWhistleDetected: Bool = false
    @Published var whistleProbability: Float = 0.0
    @Published var audioEnergy: Float = 0.0
    @Published var dominantFrequency: Float = 0.0
    @Published var stage1Probability: Float = 0.0
    @Published var stage2Probability: Float = 0.0

    // 내부 구성요소
    private let capture = AudioCaptureManager()
    private let io = AudioIOManager()
    private let yamRunner = YAMNetRunner()

    // 호루라기 감지기
    @available(macOS 15.0, *)
    private let whistleDetector = WhistleDetector()

    // ✅ 팀 공용 STT 엔진 사용 (분석 파이프라인만 사용)
    @available(macOS 15.0, *)
    private let sttEngine = STTEngine()

    private var bag = Set<AnyCancellable>()
    private var bufferCallCount = 0

    init() {
        // YAM 상태 반영
        yamRunner.$statusText
            .receive(on: DispatchQueue.main)
            .assign(to: &$yamStatus)

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
                        // 3) 호루라기 감지
                        self.handleWhistleDetection(buffer: pcm)
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

    // MARK: - 호루라기 감지
    @available(macOS 15.0, *)
    private func handleWhistleDetection(buffer: AVAudioPCMBuffer) {
        bufferCallCount += 1

        // 10번에 한 번씩 체크 (매우 빠른 반응)
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
                        print("🎵 [AudioPipeline] Whistle detected!")
                    }

                    // 3초 후 자동으로 아이콘 사라지게
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.isWhistleDetected = false
                    }
                }
            }
        }
    }
}
