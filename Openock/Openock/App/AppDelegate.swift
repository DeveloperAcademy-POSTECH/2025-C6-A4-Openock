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
    }
    NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
      (note.object as? NSWindow)?.applyLiquidGlass()
    }
  }
}
