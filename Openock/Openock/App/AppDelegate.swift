//
//  AppDelegate.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Published var windowDidBecomeKey: Bool = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false

    // STTView window에 liquid glass 효과 적용
    DispatchQueue.main.async {
      if let window = NSApp.windows.first(where: { $0.title == "" || $0.contentView != nil }) {
        window.applyLiquidGlass()
      }
    }

    NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
      DispatchQueue.main.async {
        self?.windowDidBecomeKey = true
      }
    }
  }
}
