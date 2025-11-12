//
//  LoudnessMeter.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//

import Foundation
import AVFoundation
import Accelerate
import Combine

public struct LoudnessTuning {
    public var noiseGate: Float = 0.006
    public var smoothFactor: Float = 0.10
    public var dbScale: Float = 6.2
    public var dbOffset: Float = 84.0
    public init() {}
}

public final class LoudnessMeter: ObservableObject {
    @Published public private(set) var dB: Double = 0
    private var ema: Float = 0
    private var tuning = LoudnessTuning()

    public init() {}

    public func configure(_ tuning: LoudnessTuning) { self.tuning = tuning }

    public func ingest(_ buffer: AVAudioPCMBuffer) {
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              let base = buffer.floatChannelData else { return }

        let frames = Int(buffer.frameLength)
        let ch = Int(buffer.format.channelCount)
        if frames == 0 || ch == 0 { return }

        var powerSum: Float = 0
        for c in 0..<ch {
            var meanSq: Float = 0
            vDSP_measqv(base[c], 1, &meanSq, vDSP_Length(frames))
            powerSum += meanSq
        }
        let meanPower = powerSum / Float(ch)
        var rms = sqrtf(meanPower)

        if rms < tuning.noiseGate { rms = 0 }

        let a = tuning.smoothFactor
        ema = a * rms + (1 - a) * ema

        let eps: Float = 1e-6
        let mapped = ema * tuning.dbScale + eps
        var db = 20.0 * log10(Double(mapped)) + Double(tuning.dbOffset)
        if !db.isFinite { db = 0 }
        db = max(0, min(110, db))

        DispatchQueue.main.async { self.dB = db }
    }
}
