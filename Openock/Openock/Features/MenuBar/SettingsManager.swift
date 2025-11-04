//
//  SettingsManager.swift
//  Openock
//
//  Created by Enoch on 11/1/25.
//

import SwiftUI
import Combine

final class SettingsManager: ObservableObject {
  // MARK: - Appearance
  @Published var selectedFont: String = "SF Pro"
  @Published var fontSize: CGFloat = 24
  @Published var selectedBackground: String = "black"
  
  // MARK: - Sound
  @Published var isSoundEnabled: Bool = true
  
  // MARK: - Shortcut
  @Published var isShortcutEnabled: Bool = true
  
  // MARK: - Derived color properties
  var backgroundColor: Color {
    switch selectedBackground {
    case "블랙": return .black
    case "화이트": return .white
    case "투명": return .clear
    case "커스텀": return Color.pink.opacity(0.2)
    default: return .clear
    }
  }
  
  var textColor: Color {
    switch selectedBackground {
    case "블랙": return .white
    case "화이트": return .black
    case "투명": return .gray
    case "커스텀": return .red
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
    isSoundEnabled = d.bool(forKey: "isSoundEnabled")
    isShortcutEnabled = d.bool(forKey: "isShortcutEnabled")
  }

  func save() {
    let d = UserDefaults.standard
    d.set(selectedFont, forKey: "selectedFont")
    d.set(Double(fontSize), forKey: "fontSize")
    d.set(selectedBackground, forKey: "selectedBackground")
    d.set(isSoundEnabled, forKey: "isSoundEnabled")
    d.set(isShortcutEnabled, forKey: "isShortcutEnabled")
  }
}
