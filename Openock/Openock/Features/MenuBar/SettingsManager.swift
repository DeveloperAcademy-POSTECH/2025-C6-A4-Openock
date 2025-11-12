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
  @Published var selectedBackground: String = "black"

  // 추가 기능 토글
  @Published var toggleSizeFX: Bool = true            // 자막 크기 효과
  @Published var toggleYamReactions: Bool = true      // 자막 외 소리 반응(YAMNet)
  @Published var toggleWhistle: Bool = true           // 호루라기 알림

  // 저장은 NSColor로 하고, SwiftUI에서 쓸 때는 computed Color 사용
  @Published private var customBackgroundNSColor: NSColor = .white
  @Published private var customTextNSColor: NSColor = .gray

  @Published var isColorPickerOpen = false

  // 외부에서 사용하기 쉬운 Color 인터페이스
  var customBackgroundColor: Color {
    get { Color(nsColor: customBackgroundNSColor) }
    set { if let ns = nsColor(from: newValue) { customBackgroundNSColor = ns } }
  }
  var customTextColor: Color {
    get { Color(nsColor: customTextNSColor) }
    set { if let ns = nsColor(from: newValue) { customTextNSColor = ns } }
  }

  // MARK: - Derived color properties
  var backgroundColor: Color {
    switch selectedBackground {
    case "블랙","black":   return .black
    case "화이트","white": return .white
    case "커스텀","custom": return customBackgroundColor
    default:               return .black
    }
  }
  var textColor: Color {
    switch selectedBackground {
    case "블랙","black":   return .white
    case "화이트","white": return .black
    case "커스텀","custom": return customTextColor
    default:               return .white
    }
  }

  // MARK: - Persist
  init() { load() }

  func load() {
    let d = UserDefaults.standard
    selectedFont = d.string(forKey: "selectedFont") ?? "SF Pro"
    fontSize = CGFloat(d.double(forKey: "fontSize") == 0 ? 24 : d.double(forKey: "fontSize"))
    selectedBackground = d.string(forKey: "selectedBackground") ?? "black"

    // 기능 토글
    if d.object(forKey: "toggleSizeFX") != nil { toggleSizeFX = d.bool(forKey: "toggleSizeFX") }
    if d.object(forKey: "toggleYamReactions") != nil { toggleYamReactions = d.bool(forKey: "toggleYamReactions") }
    if d.object(forKey: "toggleWhistle") != nil { toggleWhistle = d.bool(forKey: "toggleWhistle") }

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

    // 기능 토글
    d.set(toggleSizeFX, forKey: "toggleSizeFX")
    d.set(toggleYamReactions, forKey: "toggleYamReactions")
    d.set(toggleWhistle, forKey: "toggleWhistle")

    // NSColor 저장
    let bgData = try? NSKeyedArchiver.archivedData(withRootObject: customBackgroundNSColor, requiringSecureCoding: false)
    d.set(bgData, forKey: "customBackgroundColor")
    let textData = try? NSKeyedArchiver.archivedData(withRootObject: customTextNSColor, requiringSecureCoding: false)
    d.set(textData, forKey: "customTextColor")
  }

  // MARK: - Helper
  private func nsColor(from color: Color) -> NSColor? {
  #if os(macOS)
    if let cg = color.cgColor { return NSColor(cgColor: cg) }
    return nil
  #else
    return nil
  #endif
  }
}
