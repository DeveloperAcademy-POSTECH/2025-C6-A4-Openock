//
//  WindowManager.swift
//  Openock
//
//  Created by ellllly on 11/5/25.
//

import AppKit
import SwiftUI
import Combine

final class WindowManager: ObservableObject {
  static let shared = WindowManager()
  @Published var sttWindow: NSWindow? // STTView의 NSWindow를 저장
  @Published var overlayWindow: NSWindow? // EventOverlayView의 NSWindow를 저장
  private init() {
    
  }
}
