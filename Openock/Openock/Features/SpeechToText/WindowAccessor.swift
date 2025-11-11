//
//  WindowAccessor.swift
//  Openock
//
//  Created by JiJooMaeng on 11/10/25.
//

import SwiftUI

/// NSWindow에 접근하기 위한 헬퍼 뷰
struct WindowAccessor: NSViewRepresentable {
  var onResolve: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      onResolve(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
  }
}
