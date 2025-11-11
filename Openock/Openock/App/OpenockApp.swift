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
        .frame(minWidth: 600)
        .environmentObject(pipeline)
        .environmentObject(settings)
        .environmentObject(appDelegate)
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)
//    .defaultSize(width: 800)
    
    MenuBarExtra("Openock", systemImage: "character.bubble") {
      MenuBarView()
        .environmentObject(settings)
    }
    .menuBarExtraStyle(.window)
  }
}
