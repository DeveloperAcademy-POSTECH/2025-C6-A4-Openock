//
//  SettingsManager.swift
//  Openock
//
//  Created by Enoch on 11/1/25.
//

import SwiftUI
import Combine
import AppKit

final class SettingsManager: ObservableObject {
  // MARK: - Appearance
  @Published var selectedFont: String = "SF Pro"
  @Published var fontSize: CGFloat = 24

  /// 배경 프리셋: "블랙/화이트/그레이/고대비/커스텀" 또는 "black/white/gray/high-contrast/custom"
  @Published var selectedBackground: String = "black"

  /// 자막 하이라이트 프리셋: "none/red/orange/yellow/green/mint/sky/blue/purple"
  /// (한국어 키워드도 일부 대응)
  @Published var selectedHighlight: String = "yellow"

  // MARK: - Feature toggles (메뉴바 토글과 연결)
  /// 자막 크기 효과 (라우드니스 기반 폰트 크기/색 효과)
  @Published var toggleSizeFX: Bool = true
  /// 자막 외 소리 반응 (YAMNet: 함성/야유 등)
  @Published var toggleYamReactions: Bool = true
  /// 호루라기 알림
  @Published var toggleWhistle: Bool = true

  // MARK: - Custom Colors (저장은 NSColor, 외부 사용은 Color)
  @Published private var customBackgroundNSColor: NSColor = .white
  @Published private var customTextNSColor: NSColor = .gray
  @Published var isColorPickerOpen = false

  // 외부에서 쓰기 쉬운 SwiftUI.Color 인터페이스
  var customBackgroundColor: Color {
    get { Color(nsColor: customBackgroundNSColor) }
    set { if let ns = nsColor(from: newValue) { customBackgroundNSColor = ns } }
  }
  var customTextColor: Color {
    get { Color(nsColor: customTextNSColor) }
    set { if let ns = nsColor(from: newValue) { customTextNSColor = ns } }
  }

  // MARK: - Derived Colors
  var backgroundColor: Color {
    switch normalize(selectedBackground) {
    case "블랙", "black":
      return .black
    case "화이트", "white":
      return .white
    case "투명", "clear":
      return .clear
    case "고대비", "high-contrast", "high_contrast", "highcontrast":
      // HEAD 쪽 의도 유지: 고대비는 노란 배경
      return .yellow
    case "커스텀", "custom":
      return customBackgroundColor
    default:
      return .black
    }
  }

  var textColor: Color {
    switch normalize(selectedBackground) {
    case "블랙", "black":
      return .white
    case "화이트", "white":
      return .black
    case "투명", "clear":
      return .white
    case "고대비", "high-contrast", "high_contrast", "highcontrast":
      return .black
    case "커스텀", "custom":
      return customTextColor
    default:
      return .white
    }
  }

  /// 하이라이트 컬러 매핑 (영/한 일부 키워드 지원)
  var highlightColor: Color {
    switch normalize(selectedHighlight) {
    case "none", "없음":
      return .gray
    case "red", "빨강":
      return .red
    case "orange", "주황":
      return .orange
    case "yellow", "노랑":
      return .yellow
    case "green", "초록":
      return .green
    case "mint":
      return .mint
    case "sky", "cyan", "하늘":
      return .cyan
    case "blue", "파랑":
      return .blue
    case "purple", "보라":
      return .purple
    default:
      return .clear
    }
  }

  // MARK: - Persist
  init() { load() }

  func load() {
    let d = UserDefaults.standard
    selectedFont = d.string(forKey: "selectedFont") ?? "SF Pro"
    let storedFontSize = d.double(forKey: "fontSize")
    fontSize = CGFloat(storedFontSize == 0 ? 24 : storedFontSize)

    selectedBackground = d.string(forKey: "selectedBackground") ?? "black"
    selectedHighlight  = d.string(forKey: "selectedHighlight")  ?? "yellow"

    // 기능 토글
    if d.object(forKey: "toggleSizeFX") != nil {
      toggleSizeFX = d.bool(forKey: "toggleSizeFX")
    }
    if d.object(forKey: "toggleYamReactions") != nil {
      toggleYamReactions = d.bool(forKey: "toggleYamReactions")
    }
    if d.object(forKey: "toggleWhistle") != nil {
      toggleWhistle = d.bool(forKey: "toggleWhistle")
    }

    // NSColor 복원
    if let bgData = d.data(forKey: "customBackgroundColor"),
       let ns = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgData) {
      customBackgroundNSColor = ns
    }
    if let textData = d.data(forKey: "customTextColor"),
       let ns = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textData) {
      customTextNSColor = ns
    }
  }

  func save() {
    let d = UserDefaults.standard
    d.set(selectedFont, forKey: "selectedFont")
    d.set(Double(fontSize), forKey: "fontSize")
    d.set(selectedBackground, forKey: "selectedBackground")
    d.set(selectedHighlight, forKey: "selectedHighlight")

    // 기능 토글 저장
    d.set(toggleSizeFX, forKey: "toggleSizeFX")
    d.set(toggleYamReactions, forKey: "toggleYamReactions")
    d.set(toggleWhistle, forKey: "toggleWhistle")

    // NSColor 저장
    let bgData = try? NSKeyedArchiver.archivedData(withRootObject: customBackgroundNSColor, requiringSecureCoding: false)
    d.set(bgData, forKey: "customBackgroundColor")
    let textData = try? NSKeyedArchiver.archivedData(withRootObject: customTextNSColor, requiringSecureCoding: false)
    d.set(textData, forKey: "customTextColor")
  }

  // MARK: - Helpers
  private func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func nsColor(from color: Color) -> NSColor? {
  #if os(macOS)
    if let cg = color.cgColor { return NSColor(cgColor: cg) }
    return nil
  #else
    return nil
  #endif
  }
}
