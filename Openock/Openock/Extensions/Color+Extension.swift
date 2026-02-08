//
//  Color+Extension.swift
//  Openock
//
//  Created by Enoch on 11/11/25.
//

import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: UInt64
    switch hex.count {
    case 6: // RGB (without alpha)
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (255, 255, 255) // Default to white in case of an error
    }
    self.init(
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255
    )
  }
  
  // MARK: - Color -> HEX 변환
  func toHex() -> String? {
#if os(macOS)
    let nsColor = NSColor(self)
    guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return nil }
    let r = rgbColor.redComponent
    let g = rgbColor.greenComponent
    let b = rgbColor.blueComponent
#else
    let uiColor = UIColor(self)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
#endif
    
    let rgb = Int(r * 255) << 16 |
    Int(g * 255) << 8 |
    Int(b * 255)
    return String(format: "%06X", rgb)
  }
  
  // MARK: - Custom Colors
  /// Primary
  static let bsMain = Color(hex: "#4F3CEC")
  static let bsSub1 = Color(hex: "#7E71F1")
  static let bsSub2 = Color(hex: "#EDEBFD")
  
  /// text-bg
  static let bsTextBackgroundWhite = Color(hex: "#FFFFFF")
  static let bsTextBackgroundBlack = Color(hex: "#282828")
  static let bsTextBackgroundGray = Color(hex: "#959595")
  static let bsTextBackgroundYellow = Color(hex: "#FFFF00")
  static let bsOutlineWhite = Color(hex: "#FFFFFF")
  static let bsOutlineBlack = Color(hex: "#282828")
  static let bsTextBackgroundHighContrast = Color(hex: "#000000")
  static let bsSettingsTitleBackground = Color(hex: "#F9F9F9").opacity(0.1)
  
  /// mode bg
  static let bsModeBackgroundWhite = Color(hex: "#FFFFFF").opacity(0.8)
  static let bsModeBackgroundBlack = Color(hex: "#282828").opacity(0.8)
  static let bsModeBackgroundGray = Color(hex: "#959595").opacity(0.8)
  static let bsModeBackgroundHighContrast = Color(hex: "#FFFF00").opacity(0.8)
  
  /// gray scale
  static let bsGrayScale1 = Color(hex: "#5E5E5E")
  static let bsGrayScale2 = Color(hex: "#AEAEB2")
  static let bsGrayScale3 = Color(hex: "#D9D9D9")
  static let bsGrayScale4 = Color(hex: "#EDEDED")
  static let bsGrayScale5 = Color(hex: "#FBFBFB")
  
  /// onboarding
  static let bsGrayGlass = Color(hex: "#FBFBFB").opacity(0.3)

  /// index
  static let bsIndexRed = Color(hex: "#FF383C")
  static let bsIndexOrange = Color(hex: "#FF8D28")
  static let bsIndexYellow = Color(hex: "#FFCC00")
  static let bsIndexGreen = Color(hex: "#34C759")
  static let bsIndextill = Color(hex: "#00C8B3")
  static let bsIndexLightBlue = Color(hex: "#00C0E8")
  static let bsIndexBlue = Color(hex: "#0088FF")
  static let bsIndexPurple = Color(hex: "#6155F5")
}
