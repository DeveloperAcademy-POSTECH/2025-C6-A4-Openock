//
//  OpenockApp.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//
//

import SwiftUI

@main
struct OpenockApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var pipeline = AudioPipeline()
  @StateObject private var settings  = SettingsManager()
  
  // State to hold the main window instance
  @State private var mainWindow: NSWindow?

  // ↓ SwiftUI에서 변경 가능한 상태로 보관 (body 안에서도 대입 가능)
  @State private var onoffManager: OnOffManager? = nil

  var body: some Scene {
    WindowGroup {
        STTView()
            .frame(minWidth: 600)
            .environmentObject(pipeline)
            .environmentObject(settings)
            .environmentObject(appDelegate)
            .background(WindowAccessor(onResolve: { window in
                // Only set the window once.
                if mainWindow == nil {
                    mainWindow = window
                }
            })) // Capture the window
            .task {
              // AppDelegate에 pipeline 연결
              appDelegate.audioPipeline = pipeline

              // 한 번만 생성
              if onoffManager == nil {
                onoffManager = OnOffManager(pipeline: pipeline, settings: settings)
              }
            }
            .onChange(of: mainWindow) { oldWindow, newWindow in
                // Once the main window is available, show the onboarding window relative to it.
                if let window = newWindow {
                    OnboardingWindowManager.shared.show(relativeTo: window)
                }
            }
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)

    // 🔧 여기 수정
    MenuBarExtra {
      MenuBarView()
        .environmentObject(settings)
    } label: {
      Image("setting_logo")
        .renderingMode(.original)
        .symbolRenderingMode(.none)
        .resizable()
        .scaledToFit()
        .frame(width: 12, height: 12)   // 필요하면 크기 조절

    }
    .menuBarExtraStyle(.window)
  }
}
