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
  @StateObject private var pipeline = AudioPipeline()
    @StateObject private var settings  = SettingsManager()

  var body: some Scene {
    WindowGroup {
      STTView()
        .environmentObject(pipeline)    // ✅ 추가
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
