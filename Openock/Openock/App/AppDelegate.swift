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
  weak var audioPipeline: AudioPipeline?

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

  func applicationWillTerminate(_ notification: Notification) {
    print("🛑 [AppDelegate] Application terminating - cleaning up audio resources")

    // MainActor에서 동기적으로 cleanup 수행
    let semaphore = DispatchSemaphore(value: 0)

    DispatchQueue.main.async { [weak self] in
      self?.audioPipeline?.stop()
      print("✅ [AppDelegate] Audio cleanup completed")
      semaphore.signal()
    }

    // cleanup이 완료될 때까지 최대 2초 대기
    _ = semaphore.wait(timeout: .now() + 2.0)
    print("✅ [AppDelegate] Termination cleanup finished")
  }
}
