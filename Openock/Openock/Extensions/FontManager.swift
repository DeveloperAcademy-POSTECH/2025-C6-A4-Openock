//
//  FontManager.swift
//  Openock
//
//  Created by Enoch on 11/4/25.
//

import SwiftUI
import AppKit

extension NSFontManager {
  static var installedFontNames: [String] {
    NSFontManager.shared.availableFonts.sorted()
  }
}
