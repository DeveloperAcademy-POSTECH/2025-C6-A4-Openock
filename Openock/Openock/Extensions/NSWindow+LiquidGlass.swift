//
//  NSWindow+LiquidGlass.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import AppKit

extension NSWindow {
  func applyLiquidGlass() {
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
  }
}
