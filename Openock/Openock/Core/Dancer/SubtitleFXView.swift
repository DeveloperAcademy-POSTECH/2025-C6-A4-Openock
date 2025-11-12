//
//  SubtitleFXView.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//

import SwiftUI

/// 규칙
/// - 렌더링은 하나의 Text(AttributedString)로 처리
/// - "증가분 tail"에만 현재 스타일(크기/색)을 **영구 적용**
/// - 과거 글자 크기/색은 절대 바뀌지 않음
public struct SubtitleFXView: View {
    public let text: String
    public let baseFontName: String
    public let baseFontSize: CGFloat
    public let baseColor: Color
    public let style: SubtitleStyle          // FXEngine가 계산한 현재 tail 스타일
    public let lineSpacing: CGFloat
    public let textAlignment: TextAlignment   // ✅ 추가: 정렬 제어 (기본 .leading)

    @State private var rendered: AttributedString = .init("") // 누적 결과
    @State private var lastText: String = ""                  // 직전 원문

    public init(
        text: String,
        baseFontName: String,
        baseFontSize: CGFloat,
        baseColor: Color,
        style: SubtitleStyle,
        lineSpacing: CGFloat,
        textAlignment: TextAlignment = .leading
    ) {
        self.text = text
        self.baseFontName = baseFontName
        self.baseFontSize = baseFontSize
        self.baseColor = baseColor
        self.style = style
        self.lineSpacing = lineSpacing
        self.textAlignment = textAlignment
    }

    public var body: some View {
        Text(rendered)
            .textSelection(.enabled)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(textAlignment)  // ✅ 적용
            .frame(maxWidth: .infinity, alignment: frameAlignment(for: textAlignment))
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { applyDiff(newText: text) }
            .onChange(of: text) { applyDiff(newText: $0) }
    }

    private func frameAlignment(for t: TextAlignment) -> Alignment {
        switch t {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

private extension SubtitleFXView {
    // 공통 prefix 길이(문자 단위)
    func lcpCount(_ a: String, _ b: String) -> Int {
        let ac = Array(a)
        let bc = Array(b)
        let n = min(ac.count, bc.count)
        var i = 0
        while i < n, ac[i] == bc[i] { i += 1 }
        return i
    }

    // rendered의 뒷부분을 문자 수 기준으로 제거(교체 상황)
    func dropTailFromRendered(_ dropCount: Int) {
        guard dropCount > 0 else { return }
        let total = rendered.characters.count
        let keep = max(0, total - dropCount)
        let s = rendered.startIndex
        let cut = rendered.index(s, offsetByCharacters: keep)
        rendered = AttributedString(rendered[s..<cut]) // 앞부분만 남김
    }

    // 현재 스타일로 tail 생성(과거 글자엔 영향 없음)
    func makeTailAttributed(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        var c = AttributeContainer()
        c.font = .custom(baseFontName, size: baseFontSize + style.extraSize)
        c.foregroundColor = (style.color ?? baseColor)
        if style.extraSize >= 8 { c.inlinePresentationIntent = .stronglyEmphasized }
        a.setAttributes(c)
        return a
    }

    // 입력 텍스트 변화분만 반영
    func applyDiff(newText: String) {
        guard newText != lastText else { return }

        if lastText.isEmpty {
            // 최초
            rendered.append(makeTailAttributed(newText))
            lastText = newText
            return
        }

        let keep = lcpCount(lastText, newText)

        // 1) 이전 텍스트의 변경된 suffix 제거
        let oldSuffix = lastText.count - keep
        dropTailFromRendered(oldSuffix)

        // 2) 새 텍스트의 증가분을 현재 스타일로 append
        let newSuffix = String(newText.dropFirst(keep))
        if !newSuffix.isEmpty {
            rendered.append(makeTailAttributed(newSuffix))
        }

        lastText = newText
    }
}
