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

  var body: some Scene {
    WindowGroup {
      STTView()
        .environmentObject(sttEngine)
        .frame(minWidth: 600, minHeight: 200)
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)
    .defaultSize(width: 800, height: 300)

    MenuBarExtra("Openock", systemImage: "character.bubble") {
      MenuBarView()
    }
    .menuBarExtraStyle(.window)
  }
}
