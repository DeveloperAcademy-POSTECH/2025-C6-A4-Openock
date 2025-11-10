//
//  AppDelegate.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false
    for window in NSApplication.shared.windows {
      window.applyLiquidGlass()
      window.level = .floating
      window.collectionBehavior.insert(.canJoinAllSpaces)
      window.collectionBehavior.insert(.fullScreenAuxiliary)
    }
    NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
      guard let w = note.object as? NSWindow else { return }
      w.applyLiquidGlass()
      w.level = .floating
      w.collectionBehavior.insert(.canJoinAllSpaces)
      w.collectionBehavior.insert(.fullScreenAuxiliary)
    }
  }
}
