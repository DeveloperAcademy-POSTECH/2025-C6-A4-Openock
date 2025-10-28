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
  private var popover: NSPopover?

  init() {
    setupMenuBar()
  }

  private func setupMenuBar() {
    // Status Item 생성
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.title = "OO"
      button.action = #selector(togglePopover)
      button.target = self
    }

    // Popover 설정
    popover = NSPopover()
    popover?.contentSize = NSSize(width: 200, height: 100)
    popover?.behavior = .transient
    popover?.contentViewController = NSHostingController(rootView: MenuBarView())
  }

  @objc private func togglePopover() {
    guard let popover = popover else { return }
    guard let button = statusItem?.button else { return }

    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }
}
