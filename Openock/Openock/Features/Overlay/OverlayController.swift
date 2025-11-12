//
//  OverlayController.swift
//  Openock
//
//  Created by ellllly on 11/12/25.
//
import AppKit
import SwiftUI

final class OverlayController {
  static let shared = OverlayController()
  private init() {}

  private var windows: [NSWindow] = []
  private var animating: Bool = false

  func present(cue: YamCue, total: TimeInterval) {
    guard !animating else { return }
    animating = true

    tearDownOverlays(&windows)

    windows = makeOverlayWindows(for: cue, total: total) { [weak self] in
      guard let self else { return }
      tearDownOverlays(&self.windows)
      self.animating = false
    }
    windows.forEach { $0.orderFrontRegardless() }
  }
  
  /// 오버레이 윈도우 생성
  private func makeOverlayWindows(for cue: YamCue, total: TimeInterval, onFinish: @escaping () -> Void) -> [NSWindow] {
    NSScreen.screens.map { screen in
      let win = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen
      )
      win.level = .screenSaver
      win.isOpaque = false
      win.backgroundColor = .clear
      win.ignoresMouseEvents = true
      win.hasShadow = false
      win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      win.setFrame(screen.frame, display: true)

      let host = NSHostingView(rootView: OverlayTextView(cue: cue, total: total) {
        onFinish()
      })
      host.frame = win.contentRect(forFrameRect: screen.frame)
      host.autoresizingMask = [.width, .height]
      win.contentView = host
      return win
    }
  }
  /// 오버레이 윈도우 제거
  private func tearDownOverlays(_ windows: inout [NSWindow]) {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
