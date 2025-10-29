//
//  MenuBarController.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import AppKit
import SwiftUI

final class MenuBarController {
  private var statusItem: NSStatusItem?
  private var panel: NSPanel?

  init() {
    setupMenuBar()
  }

  deinit {
    cleanup()
  }

  private func setupMenuBar() {
    // Status Item 생성
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.title = "O"
      button.action = #selector(togglePanel)
      button.target = self
    }

    // Panel 설정
    panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 346, height: 443),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel?.backgroundColor = .clear
    panel?.isOpaque = false
    panel?.level = .popUpMenu
    panel?.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

    let hostingView = NSHostingController(rootView: MenuBarView())
    hostingView.view.frame = NSRect(x: 0, y: 0, width: 346, height: 443)
    panel?.contentViewController = hostingView

    if let contentView = panel?.contentView {
      contentView.wantsLayer = true
      contentView.layer?.cornerRadius = 10
      contentView.layer?.masksToBounds = true
    }

    if let containerView = panel?.contentView?.superview {
      containerView.wantsLayer = true
      containerView.layer?.cornerRadius = 10
      containerView.layer?.masksToBounds = true
      containerView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    panel?.hasShadow = true
  }

  func cleanup() {
    panel?.close()
    panel = nil

    if let statusItem = statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  @objc private func togglePanel() {
    guard let panel = panel else { return }
    guard let button = statusItem?.button else { return }

    if panel.isVisible {
      panel.close()
    } else {
      // 버튼 위치 계산
      let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
      let panelX = buttonFrame.midX - panel.frame.width / 2
      let panelY = buttonFrame.minY - panel.frame.height - 8

      panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
      panel.makeKeyAndOrderFront(nil)

      // 외부 클릭 시 닫기
      NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
        if let panel = self?.panel, panel.isVisible {
          let location = event.locationInWindow
          if !panel.frame.contains(location) {
            panel.close()
          }
        }
      }
    }
  }
}
