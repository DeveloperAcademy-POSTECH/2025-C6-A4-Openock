//
//  WindowResizeDelegate.swift
//  Openock
//
//  Created by JiJooMaeng on 11/10/25.
//

import AppKit

/// 창 높이 조절 방지를 위한 Delegate
final class WindowResizeDelegate: NSObject, NSWindowDelegate {
  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    // 높이는 현재 높이로 고정, 가로만 조절 가능
    return NSSize(width: frameSize.width, height: sender.frame.height)
  }
}
