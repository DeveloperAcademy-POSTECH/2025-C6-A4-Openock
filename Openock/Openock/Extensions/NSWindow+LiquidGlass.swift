//
//  NSWindow+LiquidGlass.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import AppKit

extension NSWindow {
  func applyLiquidGlass() {
    print("🔧 applyLiquidGlass() called on window: \(self)")
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    titlebarSeparatorStyle = .none
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    print("✅ Liquid glass applied - fullSizeContentView: \(styleMask.contains(.fullSizeContentView))")
  }
}
