//
//  SubtitleFXEngine.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Subtitle Style (개별 자막 tail에 적용, 과거 자막은 불변)
public struct SubtitleStyle: Equatable {
    public var extraSize: CGFloat   // base 폰트에 더할 pt (상대 확대 결과)
    public var color: Color?        // nil이면 현재 기본 텍스트 색 유지
    public static let neutral = SubtitleStyle(extraSize: 0, color: nil)
}

// MARK: - 규칙 정의 (확대·색상 보간 등)
public struct SubtitleFXRules {
    // 임계값 (설정)
    public var stepStart: Double = 30      // 단계적 확대 시작 dB
    public var stepEnd:   Double = 75      // 단계적 확대 끝 dB
    public var colorStart: Double = 75     // 색 보간 시작
    public var colorEnd:   Double = 90     // 색 보간 끝

    // 확대 규칙(원래 24pt 기준 수치 → 실제 baseFontSize에 비례 변환)
    public var stepWidthDB: Double = 9
    public var perStepPointsAt24pt: CGFloat = 4   // +4pt (24pt 기준)
    public var stepMaxPointsAt24pt: CGFloat = 20  // 최대 +20pt (24pt 기준)

    // 색 보간 구간에서 추가 크기(24pt 기준 +최대 8pt → 실제는 비례)
    public var colorExtraMaxAt24pt: CGFloat = 8

    // 기본 노랑(라이트/다크에서 공통 타겟)
    public var strongYellow: Color = Color(.sRGB, red: 1.0, green: 0.835, blue: 0.0, opacity: 1.0) // #FFD500 근처

    public init() {}
}

// MARK: - 메인 FX 엔진
public final class SubtitleFXEngine: ObservableObject {
    @Published public private(set) var style: SubtitleStyle = .neutral
    private var rules = SubtitleFXRules()

    public init() {}
    public func configure(_ rules: SubtitleFXRules) { self.rules = rules }

    /// 데시벨 → (상대)크기/색 계산.
    /// - Parameters:
    ///   - dB: 현재 라우드니스
    ///   - baseFontSize: 설정의 현재 글꼴 크기 (상대 확대 기준)
    ///   - baseTextColor: 설정의 현재 글꼴 색 (보간 시작색)
    ///   - selectedBackground: "블랙" | "화이트" | "커스텀"
    public func update(
        dB: Double,
        baseFontSize: CGFloat,
        baseTextColor: Color,
        selectedBackground: String
    ) {
        // 24pt 기준 값을 현재 기준으로 스케일
        let nominal: CGFloat = 24
        let scale = max(0.5, min(4.0, baseFontSize / nominal)) // 과도한 스케일 방지
        let perStepPoints = rules.perStepPointsAt24pt * scale
        let stepMaxPoints = rules.stepMaxPointsAt24pt * scale
        let colorExtraMax = rules.colorExtraMaxAt24pt * scale

        var extra: CGFloat = 0
        var color: Color? = nil

        // 30~75 dB: 계단형 확대 (상대 pt)
        if dB >= rules.stepStart {
            let clamped = min(dB, rules.stepEnd)
            let steps = max(0, floor((clamped - rules.stepStart) / rules.stepWidthDB))
            extra += min(CGFloat(steps) * perStepPoints, stepMaxPoints)
        }

        // 목표 하이라이트 색 결정
        // - 라이트/다크: 강한 노랑 고정
        // - 커스텀: 글자색의 보색(Complement)
        let highlight: Color = {
            if selectedBackground == "커스텀" {
                return complementaryColor(of: baseTextColor)
            } else {
                return rules.strongYellow
            }
        }()

        // 75~90 dB: baseTextColor → highlight 로 보간 + 상대 크기 추가
        if dB >= rules.colorStart && dB < rules.colorEnd {
            let t = CGFloat((dB - rules.colorStart) / (rules.colorEnd - rules.colorStart)) // 0~1
            color = lerpColor(from: baseTextColor, to: highlight, t: t)
            extra += t * colorExtraMax
        } else if dB >= rules.colorEnd {
            color = highlight
            extra += colorExtraMax
        }

        let newStyle = SubtitleStyle(extraSize: extra, color: color)
        if newStyle != style {
            DispatchQueue.main.async { self.style = newStyle }
        }
    }
}

// MARK: - Color Helpers

/// RGB 기반 선형 보간 (테마 간 안전하게)
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

/// Color → RGBA 추출 (macOS/iOS 안전하게)
private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
#if os(macOS)
    // NSColor 변환 실패 시 기본값
    guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return (1,1,1,1) }
    return (nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent, nsColor.alphaComponent)
#else
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if !UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) {
        return (1,1,1,1)
    }
    return (r, g, b, a)
#endif
}

/// 글자색의 **보색**(Complement) 계산 (HSB 기준, nil 접근 방지)
private func complementaryColor(of color: Color) -> Color {
#if os(macOS)
    // 안전하게 NSColor 변환
    guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else {
        // fallback: 밝은 노랑톤 (변환 실패 시)
        return Color(.sRGB, red: 1.0, green: 0.9, blue: 0.6)
    }

    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

    // 180° 회전 (보색)
    let compH = fmod(h + 0.5, 1.0)
    let compS = max(0.35, min(1.0, s)) // 채도 보정
    let compB = max(0.55, min(1.0, b)) // 명도 보정

    return Color(hue: Double(compH), saturation: Double(compS), brightness: Double(compB), opacity: Double(a))
#else
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if !UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) {
        // fallback
        return Color(.sRGB, red: 1.0, green: 0.9, blue: 0.6)
    }
    let cr = 1 - r, cg = 1 - g, cb = 1 - b
    let clamp: (CGFloat)->CGFloat = { max(0.0, min(1.0, $0)) }
    return Color(.sRGB,
                 red: Double(clamp(cr)),
                 green: Double(clamp(cg)),
                 blue: Double(clamp(cb)),
                 opacity: Double(a))
#endif
}
