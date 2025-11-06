import Foundation
import AVFoundation
import Combine

enum YamCue { case cheer, boo }

final class YAMNetRunner: ObservableObject {
    @Published var statusText: String = "YAMNet: idle"
    @Published var cue: YamCue?   // 👈 STTView로 신호 전달

    private let yam = YAMNetLite()
    private let inferQ = DispatchQueue(label: "yamnet.infer.queue") // 직렬

    // 16kHz 모노 파형 누적 버퍼
    private var ring: [Float] = []
    private let target = 15_600

    // 입력 포맷을 16kHz 모노로 바꾸는 컨버터 (필요 시 생성/갱신)
    private var converter: AVAudioConverter?

    func ingest(_ inBuf: AVAudioPCMBuffer) {
        // 오디오 콜백 스레드 → 백그라운드 직렬 큐
        let copy = inBuf.copy() as! AVAudioPCMBuffer
        inferQ.async { [weak self] in
            guard let self else { return }

            // 1) 16kHz 모노 float32로 변환
            guard let mono16k = self.toMono16k(copy) else { return }
            guard let ch0 = mono16k.floatChannelData?[0] else { return }
            let frames = Int(mono16k.frameLength)
            self.ring.append(contentsOf: UnsafeBufferPointer(start: ch0, count: frames))

            // 2) 정확히 15,600 샘플씩만 추론
            while self.ring.count >= self.target {
                let window = Array(self.ring.prefix(self.target))
                self.ring.removeFirst(self.target)

                // topK를 충분히 크게 잡아 필요한 라벨 점수 확보
                let res = self.yam.classify(waveform: window, topK: 521)
                let line = res.topK
                    .prefix(3)
                    .map { "\($0.label) \(String(format: "%.2f", $0.score))" }
                    .joined(separator: ", ")

                // 점수 맵(라벨은 소문자 비교)
                var score: [String: Float] = [:]
                for (label, s) in res.topK {
                    score[label.lowercased()] = s
                }

                // 임계치 판정
                let cheerScore = max(score["cheering"] ?? 0, score["crowd"] ?? 0)
                let booScore   = score["vehicle"] ?? 0
                let cheerHit = cheerScore >= 0.13
                let booHit   = booScore   >= 0.2

                DispatchQueue.main.async {
                    self.statusText = line.isEmpty ? "YAMNet: (no result)" : "YAMNet: \(line)"

                    // 둘 다 충족 시 큰 값 우선
                    if cheerHit && booHit {
                        self.cue = (cheerScore >= booScore) ? .cheer : .boo
                    } else if cheerHit {
                        self.cue = .cheer
                    } else if booHit {
                        self.cue = .boo
                    }
                }
            }
        }
    }

    // 입력 버퍼 포맷 → 16kHz mono float32
    private func toMono16k(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let targetFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: 16_000,
                                      channels: 1,
                                      interleaved: false)!
        // 이미 16k/mono/float32면 그대로 사용
        if src.format.sampleRate == 16_000 &&
           src.format.commonFormat == .pcmFormatFloat32 &&
           src.format.channelCount == 1 {
            return src
        }
        // 컨버터 준비/갱신
        if converter == nil || converter?.inputFormat != src.format || converter?.outputFormat != targetFmt {
            converter = AVAudioConverter(from: src.format, to: targetFmt)
            converter?.primeMethod = .none
        }
        guard let converter,
              let out = AVAudioPCMBuffer(pcmFormat: targetFmt,
                                         frameCapacity: AVAudioFrameCount(Double(src.frameLength) * (16_000.0 / src.format.sampleRate))) else {
            return nil
        }
        var err: NSError?
        let ib: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return src
        }
        converter.convert(to: out, error: &err, withInputFrom: ib)
        if let _ = err { return nil }
        return out
    }
}
