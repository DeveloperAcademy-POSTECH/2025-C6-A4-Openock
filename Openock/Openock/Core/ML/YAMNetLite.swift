import Foundation
import AVFoundation
import Accelerate
import TFLiteC

public struct YAMNetResult {
    public let topK: [(label: String, score: Float)]
    public let rawScores: [Float]      // 521-class scores
    public let embedding: [Float]?     // (some models expose this as a 2nd output)
}

public final class YAMNetLite {

    // MARK: - Constants
    public static let sampleRate: Double = 16_000
    private static let labelsCSVName   = "yamnet_class_map"         // fallback: yamnet_labels.csv
    private static let labelsTXTName   = "yamnet_label_list"     // preferred: yamnet_label_list.txt
    private static let modelFilename   = "yamnet"                // yamnet.tflite
    private static let modelExt        = "tflite"
    private let kExpectedSamples       = 15_600                  // LiteRt fixed length: 0.975s @16k

    // MARK: - TFLite handles
    private var model: OpaquePointer?
    private var options: OpaquePointer?
    private var interpreter: OpaquePointer?

    // MARK: - Labels
    private let labels: [String]

    // MARK: - Init / Deinit
    public init(threads: Int32 = 2) {
        // 1) Load labels (txt → csv fallback)
        self.labels = YAMNetLite.loadLabels() ?? []

        // 2) Load model
        guard
            let modelPath = Bundle.main.path(forResource: Self.modelFilename, ofType: Self.modelExt),
            FileManager.default.fileExists(atPath: modelPath)
        else {
            fatalError("[YAMNetLite] yamnet.tflite not found in app bundle.")
        }

        model = TfLiteModelCreateFromFile(modelPath)
        precondition(model != nil, "[YAMNetLite] TfLiteModelCreateFromFile failed")

        // 3) Options
        options = TfLiteInterpreterOptionsCreate()
        TfLiteInterpreterOptionsSetNumThreads(options, threads)

        // 4) Interpreter
        interpreter = TfLiteInterpreterCreate(model, options)
        precondition(interpreter != nil, "[YAMNetLite] TfLiteInterpreterCreate failed")

        // 5) Allocate tensors (initial)
        let status = TfLiteInterpreterAllocateTensors(interpreter)
        precondition(status == kTfLiteOk, "[YAMNetLite] AllocateTensors failed")
    }

    deinit {
        if let i = interpreter { TfLiteInterpreterDelete(i) }
        if let o = options { TfLiteInterpreterOptionsDelete(o) }
        if let m = model { TfLiteModelDelete(m) }
    }

    // MARK: - Public API

    /// Classify an AVAudioPCMBuffer. Ensures 16kHz mono Float32, then forwards.
    public func classify(buffer: AVAudioPCMBuffer, topK k: Int = 5) -> YAMNetResult {
        let mono16k = ensureMono16kFloat(buffer: buffer)
        let waveform = Array(
            UnsafeBufferPointer(
                start: mono16k.floatChannelData![0],
                count: Int(mono16k.frameLength)
            )
        )
        return classify(waveform: waveform, topK: k)
    }

    /// Classify a raw 16kHz mono Float32 waveform.
    /// LiteRt spec: **exactly 15,600 samples** (0.975 s). We resize to that.
    public func classify(waveform: [Float], topK k: Int = 5) -> YAMNetResult {
        guard !waveform.isEmpty else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }
        guard var input = TfLiteInterpreterGetInputTensor(interpreter, 0) else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Validate input tensor type
        guard TfLiteTensorType(input) == kTfLiteFloat32 else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Adjust input dims to fixed-length:
        //  - rank 1: [15600]
        //  - rank 2: [1, 15600]
        let rank = Int(TfLiteTensorNumDims(input))
        switch rank {
        case 1:
            var dims: [Int32] = [Int32(kExpectedSamples)]
            _ = dims.withUnsafeBufferPointer {
                TfLiteInterpreterResizeInputTensor(interpreter, 0, $0.baseAddress, Int32($0.count))
            }
        case 2:
            var dims: [Int32] = [1, Int32(kExpectedSamples)]
            _ = dims.withUnsafeBufferPointer {
                TfLiteInterpreterResizeInputTensor(interpreter, 0, $0.baseAddress, Int32($0.count))
            }
        default:
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        guard TfLiteInterpreterAllocateTensors(interpreter) == kTfLiteOk else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Refresh input after allocation
        input = TfLiteInterpreterGetInputTensor(interpreter, 0)

        // Fit waveform to exactly 15,600 samples
        var work = waveform
        if work.count != kExpectedSamples {
            work = fitWaveform(work, toCount: kExpectedSamples)
        }

        // Byte size must match exactly
        let mustBytes = kExpectedSamples * MemoryLayout<Float>.stride
        let currBytes = Int(TfLiteTensorByteSize(input))
        guard currBytes == mustBytes else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Safe copy
        var copyStatus = kTfLiteOk
        work.withUnsafeBytes { raw in
            copyStatus = TfLiteTensorCopyFromBuffer(input, raw.baseAddress, mustBytes)
        }
        if copyStatus != kTfLiteOk {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Invoke
        guard TfLiteInterpreterInvoke(interpreter) == kTfLiteOk else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        // Outputs
        let outCount = TfLiteInterpreterGetOutputTensorCount(interpreter)
        guard outCount >= 1 else {
            return YAMNetResult(topK: [], rawScores: [], embedding: nil)
        }

        let scores = readFloatVector(from: 0) ?? []
        let embedding = outCount >= 2 ? readFloatVector(from: 1) : nil

        let top = topK(scores: scores, k: k).map { (idx, score) in
            let label = (idx < labels.count) ? labels[idx] : "#\(idx)"
            return (label, score)
        }
        return YAMNetResult(topK: top, rawScores: scores, embedding: embedding)
    }

    // MARK: - Private helpers

    /// If too long → keep the most recent n samples.
    /// If too short → left-pad zeros so the signal is right-aligned.
    private func fitWaveform(_ x: [Float], toCount n: Int) -> [Float] {
        guard n > 0 else { return [] }
        if x.count == n { return x }
        if x.count > n {
            return Array(x.suffix(n))
        } else {
            var out = [Float](repeating: 0, count: n)
            let start = n - x.count
            out.replaceSubrange(start..<n, with: x)
            return out
        }
    }

    private func readFloatVector(from outputIndex: Int32) -> [Float]? {
        guard let t = TfLiteInterpreterGetOutputTensor(interpreter, outputIndex) else { return nil }
        let bytes = TfLiteTensorByteSize(t)
        if bytes == 0 { return [] }

        let count = Int(bytes) / MemoryLayout<Float>.stride
        var out = [Float](repeating: 0, count: count)
        let status = TfLiteTensorCopyToBuffer(t, &out, bytes)
        precondition(status == kTfLiteOk, "[YAMNetLite] CopyToBuffer failed at output \(outputIndex)")
        return out
    }

    private func topK(scores: [Float], k: Int) -> [(index: Int, score: Float)] {
        guard !scores.isEmpty else { return [] }
        return scores.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(k)
            .map { ($0.offset, $0.element) }
    }

    // MARK: - Labels loader (txt preferred, csv fallback)
    private static func loadLabels() -> [String]? {
        // 1) txt: each line is a label (preferred for LiteRt builds)
        if let txtPath = Bundle.main.path(forResource: labelsTXTName, ofType: "txt"),
           let txt = try? String(contentsOfFile: txtPath, encoding: .utf8) {
            let lines = txt
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !lines.isEmpty { return lines }
        }

        // 2) csv: use the last column per row (common old YAMNet export)
        if let csvPath = Bundle.main.path(forResource: labelsCSVName, ofType: "csv"),
           let text = try? String(contentsOfFile: csvPath, encoding: .utf8) {
            let lines = text.split(whereSeparator: \.isNewline)
            guard lines.count > 1 else { return nil }
            let labels = lines.dropFirst().compactMap { line -> String? in
                let parts = line.split(separator: ",", omittingEmptySubsequences: false)
                guard let last = parts.last else { return nil }
                var s = String(last).trimmingCharacters(in: .whitespacesAndNewlines)
                if s.first == "\"", s.last == "\"" { s = String(s.dropFirst().dropLast()) }
                return s
            }
            if !labels.isEmpty { return labels }
        }

        return nil
    }

    // MARK: - Audio conversion to 16k mono float32
    private func ensureMono16kFloat(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: Self.sampleRate,
                                   channels: 1,
                                   interleaved: false)!

        // Already 16k/mono/float32
        if buffer.format.sampleRate == target.sampleRate &&
           buffer.format.channelCount == target.channelCount &&
           buffer.format.commonFormat == target.commonFormat {
            return buffer
        }

        let converter = AVAudioConverter(from: buffer.format, to: target)!
        let ratio = Self.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: frameCapacity)!
        var err: NSError?

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: out, error: &err, withInputFrom: inputBlock)
        if let err { fatalError("[YAMNetLite] AVAudioConverter error: \(err)") }

        // If multi-channel, average to mono
        if out.format.channelCount > 1, let ptrs = out.floatChannelData {
            let frames = Int(out.frameLength)
            let ch = Int(out.format.channelCount)
            var mono = [Float](repeating: 0, count: frames)
            for c in 0..<ch {
                vDSP_vadd(ptrs[c], 1, mono, 1, &mono, 1, vDSP_Length(frames))
            }
            var div = Float(ch)
            vDSP_vsdiv(mono, 1, &div, &mono, 1, vDSP_Length(frames))
            mono.withUnsafeMutableBufferPointer { bp in
                memcpy(ptrs[0], bp.baseAddress!, frames * MemoryLayout<Float>.size)
            }
            out.frameLength = AVAudioFrameCount(frames)
        }

        return out
    }
}
