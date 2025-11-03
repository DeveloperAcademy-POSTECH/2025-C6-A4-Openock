//
//  OpenockApp.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

@main
struct OpenockApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var sttEngine = STTEngine()
  @StateObject private var settings = SettingsManager()

  var body: some Scene {
    WindowGroup {
      STTView()
        .environmentObject(sttEngine)
        .environmentObject(settings)
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)

    MenuBarExtra("Openock", systemImage: "character.bubble") {
      MenuBarView()
        .environmentObject(settings)
    }
    .menuBarExtraStyle(.window)
  }
}
