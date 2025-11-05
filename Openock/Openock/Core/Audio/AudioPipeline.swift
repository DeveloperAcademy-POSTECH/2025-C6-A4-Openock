//
//  AudioPipeline.swift
//  Openock
//
//  Created by YONGWON SEO on 11/5/25.
//

// AudioPipeline.swift
import Foundation
import AVFoundation
import Combine

final class AudioPipeline: ObservableObject {
    // 뷰가 표시할 것들
    @Published var yamStatus: String = "YAMNet: idle"
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false

    // 내부 구성요소
    private let capture = AudioCaptureManager()
    private let io = AudioIOManager()
    private let yamRunner = YAMNetRunner()

    // STT (macOS 15+)
    @available(macOS 15.0, *)
    private let sttManager = STTTranscriberManager()

    private var bag = Set<AnyCancellable>()

    init() {
        // YAM 상태 구독 → Published로 노출
        yamRunner.$statusText
            .receive(on: DispatchQueue.main)
            .assign(to: &$yamStatus)

        // STT 자막 구독 (가능한 OS에서만)
        if #available(macOS 15.0, *) {
            sttManager.$transcript
                .receive(on: DispatchQueue.main)
                .assign(to: &$transcript)
        }
    }

    // 캡처 + IO 시작
    func setupAndStart() {
        capture.setupFullSystemCapture { [weak self] deviceID in
            guard let self, let devID = deviceID else { return }

            let ok = self.io.startIO(
                deviceID: devID,
                bufferCallback: { [weak self] pcm in
                    guard let self else { return }
                    // 1) YAMNet에 던짐 (큐에서 추론)
                    self.yamRunner.ingest(pcm)
                    // 2) STT에 전달 (OS 지원 시)
                    if #available(macOS 15.0, *) {
                        self.sttManager.processAudio(buffer: pcm)
                    }
                },
                levelCallback: { _ in }
            )

            DispatchQueue.main.async {
                self.isRecording = ok
                self.isPaused = false
            }

            // STT 엔진 구동
            if #available(macOS 15.0, *) {
                Task { await self.sttManager.startTranscription() }
            }
        }
    }

    func startRecording() { // 필요 시 뷰에서 호출
        setupAndStart()
    }

    func stop() {
        io.stopIO()
        capture.cleanup()
        if #available(macOS 15.0, *) {
            sttManager.stopTranscription()
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
