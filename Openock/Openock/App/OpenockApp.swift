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
  @StateObject private var overlay = OverlayManager()
  
  
  private let windowManager = WindowManager.shared
  
  var body: some Scene {
    WindowGroup {
      STTView()
        .environmentObject(sttEngine)
        .environmentObject(settings)
        .environmentObject(overlay)
        .environmentObject(windowManager)
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)
    
    Window("EventOverlay", id: "eventOverlay") {
      EventOverlayView()
        .environmentObject(overlay)
        .environmentObject(windowManager)
        .background(Color.clear)
    }
    .windowStyle(.hiddenTitleBar)
    .windowLevel(.floating)
    
    MenuBarExtra("Openock", systemImage: "character.bubble") {
      MenuBarView()
        .environmentObject(settings)
    }
    .menuBarExtraStyle(.window)
  }
}
