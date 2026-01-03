//
//  SubtitleFXEngine.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Subtitle Style
public struct SubtitleStyle: Equatable {
    public var extraSize: CGFloat   // baseFontSize에 더해지는 값
    public var color: Color?        // tail 글자 색
    public static let neutral = SubtitleStyle(extraSize: 0, color: nil)
}

// MARK: - 규칙 정의
public struct SubtitleFXRules {
    /// 2단계 시작 dB (계단형 확대 시작)
    public var stepStart: Double = 65
    /// 2단계 종료 dB
    public var stepEnd:   Double = 83
    /// 3단계 시작 dB (색, 추가 확대 시작)
    public var colorStart: Double = 83
    /// 3단계 종료 dB (일단 고정 영역으로 취급)
    public var colorEnd:   Double = 95

    public init() {}
}

// MARK: - FX Engine
public final class SubtitleFXEngine: ObservableObject {
    @Published public private(set) var style: SubtitleStyle = .neutral
    private var rules = SubtitleFXRules()

    public func configure(_ r: SubtitleFXRules) { self.rules = r }

    /// highlightColor: AppearanceView / SettingsManager에서 선택한 강조 색
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
        //let highStart = rules.colorStart  // 75
        // let highEnd   = rules.colorEnd // 지금은 안 씀 (3단계는 고정 영역으로)

        // -------------------
        // 1단계: 0 ~ 30 dB
        //     → 크기/색 변화 없음
        // -------------------
        if dB < minDB {
            apply(extra: 0, color: nil)
            return
        }

        // -------------------
        // 2단계: 30 ~ 75 dB
        //   - 4 dB마다 +4pt 증가
        //   - 최대 +20pt
        //   - 색 변화 없음
        // -------------------
        if dB < midDB {
            let delta = dB - minDB
            let step = Int(delta / 4.0)          // 4 dB 당 1스텝
            extra = CGFloat(min(step * 4, 20))   // 최대 +20
            apply(extra: extra, color: nil)
            return
        }

        // -------------------
        // 3단계: 75 dB 이상
        //   - 크기: base + 24 로 고정
        //   - 색: highlightColor 로 고정
        //   → 더 이상 75~90 사이에서 계속 보간하지 않음
        // -------------------
        extra = 24
        color = highlightColor

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
        red:     Double(r1 + (r2 - r1) * tt),
        green:   Double(g1 + (g2 - g1) * tt),
        blue:    Double(b1 + (b2 - b1) * tt),
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
