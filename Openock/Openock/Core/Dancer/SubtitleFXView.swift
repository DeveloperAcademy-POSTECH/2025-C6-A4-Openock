//
//  SubtitleFXView.swift
//  Openock
//
//  Created by YONGWON SEO on 11/10/25.
//

import SwiftUI

/// 규칙
/// - 하나의 Text(AttributedString)로 렌더링
/// - STT가 매번 "전체 문장"을 다시 보내더라도:
///   - 이전에 존재하던 글자는 **그때의 스타일을 유지**
///   - 새로 생긴 글자만 현재 FX 스타일(크기/색)로 추가
public struct SubtitleFXView: View {
    public let text: String
    public let baseFontName: String
    public let baseFontSize: CGFloat
    public let baseColor: Color
    public let style: SubtitleStyle          // FXEngine가 계산한 현재 tail 스타일
    public let lineSpacing: CGFloat
    public let textAlignment: TextAlignment

    /// 화면에 실제로 그려진 AttributedString
    @State private var rendered: AttributedString = .init("")
    /// 직전에 STT로부터 받은 plain 텍스트
    @State private var lastText: String = ""

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
            .multilineTextAlignment(textAlignment)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: frameAlignment(for: textAlignment))
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                applyDiff(newText: text)
            }
            .onChange(of: text) { newValue in
                applyDiff(newText: newValue)
            }
    }

    private func frameAlignment(for t: TextAlignment) -> Alignment {
        switch t {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

// MARK: - LCS 기반 Diff 로직
private extension SubtitleFXView {

    /// STT에서 새 전체 문자열이 왔을 때,
    /// - lastText 와 newText 사이의 LCS를 이용해
    ///   * 유지할 글자(기존 스타일 그대로)
    ///   * 새로 생긴 글자(현재 FX 스타일로) 를 구분해서 렌더링
    func applyDiff(newText: String) {
        // 완전 동일하면 아무 것도 안 함
        guard newText != lastText else { return }

        // 최초 렌더링: 전체를 현재 스타일로 한 번에 적용
        if lastText.isEmpty {
            if !newText.isEmpty {
                rendered = makeTailAttributed(newText)
                lastText = newText
            }
            return
        }

        // 문자 배열로 변환
        let oldChars = Array(lastText)
        let newChars = Array(newText)
        let m = oldChars.count
        let n = newChars.count

        // dp[i][j] = old[0..<i], new[0..<j] 의 LCS 길이
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0..<m {
            for j in 0..<n {
                if oldChars[i] == newChars[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i][j + 1], dp[i + 1][j])
                }
            }
        }

        // LCS 경로로부터 연산 추출 (역순으로 따라간 뒤 뒤집기)
        enum Op {
            case keep(oldIndex: Int, newIndex: Int)
            case insert(newIndex: Int)
            case delete(oldIndex: Int)
        }

        var ops: [Op] = []
        var i = m
        var j = n

        while i > 0 || j > 0 {
            if i > 0, j > 0,
               oldChars[i - 1] == newChars[j - 1],
               dp[i][j] == dp[i - 1][j - 1] + 1 {
                ops.append(.keep(oldIndex: i - 1, newIndex: j - 1))
                i -= 1
                j -= 1
            } else if j > 0, (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                ops.append(.insert(newIndex: j - 1))
                j -= 1
            } else if i > 0 {
                ops.append(.delete(oldIndex: i - 1))
                i -= 1
            }
        }

        ops.reverse()

        // oldChars 의 "문자 인덱스"를 rendered 의 "character index"와 매핑
        // (지금까지는 항상 lastText 길이만큼 rendered에 문자 쌓아왔으므로 1:1 대응)
        var newRendered = AttributedString()
        var oldCharPos = 0  // lastText / rendered 에서의 문자 인덱스 (0-based)

        for op in ops {
            switch op {
            case .keep(let oldIndex, _):
                // oldIndex 위치의 문자 1개를 rendered에서 그대로 복사
                let start = rendered.index(rendered.startIndex, offsetByCharacters: oldIndex)
                let end   = rendered.index(start, offsetByCharacters: 1)
                let slice = rendered[start..<end]
                newRendered.append(slice)
                oldCharPos = oldIndex + 1

            case .insert(let newIndex):
                // 새로 생긴 글자 → 현재 FX 스타일로 tail 생성
                let ch = newChars[newIndex]
                let s  = String(ch)
                newRendered.append(makeTailAttributed(s))

            case .delete(let oldIndex):
                // oldIndex 에 있던 문자는 newText에 없음 → 버림(append 안 함)
                // oldCharPos 는 keep 에서만 사용하므로 여기서는 신경쓸 것 없음
                _ = oldIndex
            }
        }

        rendered = newRendered
        lastText = newText
    }

    /// 현재 FX 스타일로 tail 문자열 생성
    func makeTailAttributed(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        var c = AttributeContainer()
        c.font = .custom(baseFontName, size: baseFontSize + style.extraSize)
        c.foregroundColor = (style.color ?? baseColor)
        if style.extraSize >= 8 {
            c.inlinePresentationIntent = .stronglyEmphasized
        }
        a.setAttributes(c)
        return a
    }
}
