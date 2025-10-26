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
  
  var body: some Scene {
    WindowGroup {
      LiveCaptionView()
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)
  }
}
