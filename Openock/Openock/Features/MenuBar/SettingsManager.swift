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
  
  // 저장은 NSColor로 하고, SwiftUI에서 쓸 때는 computed Color 사용
  @Published private var customBackgroundNSColor: NSColor = NSColor.white
  @Published private var customTextNSColor: NSColor = NSColor.gray
  
  @Published var isColorPickerOpen = false
  
  // 외부에서 사용하기 쉬운 Color 인터페이스 (읽기/쓰기)
  var customBackgroundColor: Color {
    get { Color(nsColor: customBackgroundNSColor) }
    set {
      // Color -> NSColor 변환 시에는 cgColor를 통해 처리
      if let ns = nsColor(from: newValue) {
        customBackgroundNSColor = ns
      }
    }
  }
  var customTextColor: Color {
    get { Color(nsColor: customTextNSColor) }
    set {
      if let ns = nsColor(from: newValue) {
        customTextNSColor = ns
      }
    }
  }
  
  // MARK: - Derived color properties
  var backgroundColor: Color {
    switch selectedBackground {
    case "블랙": return .black
    case "화이트": return .white
    case "커스텀": return customBackgroundColor
    default: return .clear
    }
  }
  
  var textColor: Color {
    switch selectedBackground {
    case "블랙": return .white
    case "화이트": return .black
    case "커스텀": return customTextColor
    default: return .primary
    }
  }
  
  // MARK: - Persist
  init() {
    load()
  }
  
  func load() {
    let d = UserDefaults.standard
    selectedFont = d.string(forKey: "selectedFont") ?? "SF Pro"
    fontSize = CGFloat(d.double(forKey: "fontSize") == 0 ? 24 : d.double(forKey: "fontSize"))
    selectedBackground = d.string(forKey: "selectedBackground") ?? "black"
    if let bgData = d.data(forKey: "customBackgroundColor") {
      if let ns = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgData) {
        customBackgroundNSColor = ns
      }
    }
    
    if let textData = d.data(forKey: "customTextColor") {
      if let ns = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textData) {
        customTextNSColor = ns
      }
    }
  }
  
  func save() {
    let d = UserDefaults.standard
    d.set(selectedFont, forKey: "selectedFont")
    d.set(Double(fontSize), forKey: "fontSize")
    d.set(selectedBackground, forKey: "selectedBackground")
    
    // NSColor 를 Data 로 아카이브해서 저장
    let bgData = try? NSKeyedArchiver.archivedData(withRootObject: customBackgroundNSColor, requiringSecureCoding: false)
    d.set(bgData, forKey: "customBackgroundColor")
    
    let textData = try? NSKeyedArchiver.archivedData(withRootObject: customTextNSColor, requiringSecureCoding: false)
    d.set(textData, forKey: "customTextColor")
  }
  
  // MARK: - Helper: SwiftUI.Color -> NSColor 변환 (안전하게)
  private func nsColor(from color: Color) -> NSColor? {
  #if os(macOS)
    // Color -> CGColor -> NSColor 경로로 변환 시도
    let mirror = Mirror(reflecting: color)
    if let provider = mirror.descendant("provider") {
      let providerMirror = Mirror(reflecting: provider)
      if let cgColor = providerMirror.descendant("cgColor") as? AnyObject,
         CFGetTypeID(cgColor) == CGColor.typeID {
        return NSColor(cgColor: unsafeBitCast(cgColor, to: CGColor.self))
      }
    }

    // fallback
    if let cg = color.cgColor {
      return NSColor(cgColor: cg)
    }
    return nil
  #else
    return nil
  #endif
  }
}
