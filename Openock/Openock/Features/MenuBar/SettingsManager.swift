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
  @Published var selectedHighlight: String = "yellow"
  
  // MARK: - Derived subtitles style color properties
  var backgroundColor: Color {
    switch selectedBackground {
    case "블랙": return .black
    case "화이트": return .white
    case "그레이": return .gray
    case "고대비": return .yellow
    default: return .clear
    }
  }

  var textColor: Color {
    switch selectedBackground {
    case "블랙": return .white
    case "화이트": return .black
    case "그레이": return .white
    case "고대비": return .black
    default: return .primary
    }
  }
  
  var highlightColor: Color {
    switch selectedHighlight {
    case "none": return .gray
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "mint": return .mint
    case "sky": return .cyan
    case "blue": return .blue
    case "purple": return .purple
    default: return .clear
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
    selectedHighlight = d.string(forKey: "selectedHighlight") ?? "yellow"
  }
  
  func save() {
    let d = UserDefaults.standard
    d.set(selectedFont, forKey: "selectedFont")
    d.set(Double(fontSize), forKey: "fontSize")
    d.set(selectedBackground, forKey: "selectedBackground")
    d.set(selectedHighlight, forKey: "selectedHighlight")
  }
}
