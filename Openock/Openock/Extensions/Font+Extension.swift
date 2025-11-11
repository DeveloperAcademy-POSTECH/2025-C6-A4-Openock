//
//  Font+Extension.swift
//  Openock
//
//  Created by Enoch on 11/11/25.
//

import SwiftUI

extension Font {
  enum SFPro: String {
    case regular = "SF Pro Text Regular"
    case semibold = "SF Pro Text Semibold"
    
    /// 폰트 불러오기
    func font(size: CGFloat) -> Font {
      return .custom(self.rawValue, size: size)
    }
  }
  
  // 배경 및 글씨
  static var bsTabBarOn: Font {
    SFPro.semibold.font(size: 13)
  }
  
  // 기능 설정
  static var bsTabBarOff: Font {
    SFPro.semibold.font(size: 13)
  }
  
  // 서체, 서체 크기, 자막 스타일
  static var bsTitle: Font {
    SFPro.semibold.font(size: 11)
  }
  
  // SF Pro Regular
  static var bsFontCaption1: Font {
    SFPro.regular.font(size: 17)
  }
  
  // Font 1
  static var bsFontCaption2: Font {
    SFPro.regular.font(size: 16)
  }
  
  // 블랙, 화이트, 그레이, 고대비
  static var bsBackgroundStyleCaption: Font {
    SFPro.regular.font(size: 11)
  }
  
  // 실시간 자막 효과
  static var bsToggleCaption: Font {
    SFPro.regular.font(size: 13)
  }
}

// MARK: - Line Height 적용 View Modifier
struct LineHeight: ViewModifier {
    let fontSize: CGFloat
    let lineHeight: CGFloat
    
    func body(content: Content) -> some View {
        content
            .lineSpacing(fontSize * lineHeight - fontSize)
            .padding(.vertical, (fontSize * lineHeight - fontSize) / 2)
    }
}

extension View {
    /// - Parameters:
    ///   - lineHeight: 원하는 줄 높이 배수 (예: `1.2` → 120%).
    ///   - fontSize: 텍스트의 폰트 크기(pt).
    /// - Returns: 조정된 줄 높이가 적용된 뷰.
    ///
    /// ## 사용 예시
    /// ```swift
    /// Text("예시 텍스트입니다.")
    ///     .font(.bsTitle)
    ///     .lineHeight(fontSize: 24, lineHeight: 1.4)
    /// ```
    func lineHeight(_ lineHeight: CGFloat, fontSize: CGFloat) -> some View {
        self.modifier(LineHeight(fontSize: fontSize, lineHeight: lineHeight))
    }
}
