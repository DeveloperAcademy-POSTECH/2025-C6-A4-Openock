//
//  SubtitleFXEngine.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//
//
//  SubtitleFXEngine.swift
//  Openock
//

import Foundation
import SwiftUI
import Combine

// MARK: - Subtitle Style
public struct SubtitleStyle: Equatable {
    public var extraSize: CGFloat
    public var color: Color?
    public static let neutral = SubtitleStyle(extraSize: 0, color: nil)
}

// MARK: - 규칙 정의
public struct SubtitleFXRules {
    public var stepStart: Double = 30
    public var stepEnd:   Double = 75
    public var colorStart: Double = 75
    public var colorEnd:   Double = 90
    public init() {}
}

// MARK: - FX Engine
public final class SubtitleFXEngine: ObservableObject {
    @Published public private(set) var style: SubtitleStyle = .neutral
    private var rules = SubtitleFXRules()

    public func configure(_ r: SubtitleFXRules) { self.rules = r }

    /// highlightColor: SettingsManager에서 선택한 강조 색
    public func update(
        dB: Double,
        baseFontSize: CGFloat,
        baseTextColor: Color,
        highlightColor: Color
    ) {
        var extra: CGFloat = 0
        var color: Color? = nil

        let minDB     = rules.stepStart   // 30
        let midDB     = rules.stepEnd     // 75
        let highStart = rules.colorStart  // 75
        let highEnd   = rules.colorEnd    // 90

        // -------------------
        // 1단계: 0~30 dB
        // -------------------
        if dB < minDB {
            apply(extra: 0, color: nil)
            return
        }

        // -------------------
        // 2단계: 30~75 dB
        //   +4pt씩 증가
        //   최대 +20
        // -------------------
        if dB < midDB {
            let delta = dB - minDB
            let step = Int(delta / 4.0)          // 4 dB 당 1스텝
            extra = CGFloat(min(step * 4, 20))   // 최대 +20
            apply(extra: extra, color: nil)
            return
        }

        // -------------------
        // 3단계: 75~90 dB
        //   색상 보간
        //   크기 +20 → +24
        // -------------------
        let clamped = max(highStart, min(dB, highEnd))
        let t = CGFloat((clamped - highStart) / (highEnd - highStart)) // 0~1

        color = lerpColor(from: baseTextColor, to: highlightColor, t: t)
        extra = 20 + (4 * t)   // 20 → 24

        apply(extra: extra, color: color)
    }

    private func apply(extra: CGFloat, color: Color?) {
        let new = SubtitleStyle(extraSize: extra, color: color)
        if new != style {
            DispatchQueue.main.async { self.style = new }
        }
    }
}

// MARK: - Color Helpers
private func lerpColor(from: Color, to: Color, t: CGFloat) -> Color {
    let tt = max(0, min(1, t))
    let (r1, g1, b1, a1) = rgba(from)
    let (r2, g2, b2, a2) = rgba(to)
    return Color(
        .sRGB,
        red: Double(r1 + (r2 - r1) * tt),
        green: Double(g1 + (g2 - g1) * tt),
        blue: Double(b1 + (b2 - b1) * tt),
        opacity: Double(a1 + (a2 - a1) * tt)
    )
}

private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
#if os(macOS)
    guard let cs = NSColor(color).usingColorSpace(.sRGB) else { return (1,1,1,1) }
    return (cs.redComponent, cs.greenComponent, cs.blueComponent, cs.alphaComponent)
#else
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if !UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) { return (1,1,1,1) }
    return (r, g, b, a)
#endif
}
