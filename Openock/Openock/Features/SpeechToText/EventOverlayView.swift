//
//  EventOverlayView.swift
//  Openock
//
//  Created by ellllly on 11/5/25.
//

import SwiftUI
import AppKit

struct EventOverlayView: View {
  @EnvironmentObject var overlay: OverlayManager
  @EnvironmentObject var windowManager: WindowManager
  
  var body: some View {
    ZStack {
      Color.clear.ignoresSafeArea()
      if overlay.isVisible && overlay.currentText != "해당 없음" {
        VStack {
          EventBadge(title: overlay.currentText, color: badgeColor(for: overlay.currentText))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: overlay.currentText)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        //.fixedSize(horizontal: false, vertical: true)
      }
    }
    .background(Color.clear)
    .background(WindowConfigurator())
  }
  
}

struct EventBadge: View {
  let title: String
  let color: Color
  var body: some View {
    Text(title)
      .font(.system(size: 18, weight: .heavy))
      .foregroundColor(.white)
    //.padding(.horizontal, 16)
    //.padding(.vertical, 8)
      .background(Capsule().fill(color.opacity(0.92)))
      .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 6)
      .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
  }
}

func badgeColor(for category: String) -> Color {
  switch category {
  case "득점": return .orange
  case "반칙": return .red
  case "옐로 카드": return .yellow
  case "레드 카드": return .red.opacity(0.85)
  case "전반전 종료": return .blue
  case "후반전 시작": return .green
  default: return .gray
  }
}

private struct WindowConfigurator: NSViewRepresentable {
  @EnvironmentObject var windowManager: WindowManager
  
  func makeNSView(context: Context) -> NSView {
    let v = NSView()
    DispatchQueue.main.async {
      if let w = v.window {
        
        windowManager.overlayWindow = w
        
        w.styleMask = [.borderless] // ⭐️ [핵심] 테두리 없는 투명 창을 만듭니다.
        w.isOpaque = false // ⭐️ [핵심] 불투명도를 false로 설정하여 배경이 투명하게 합니다.
        w.backgroundColor = .clear // ⭐️ [핵심] 배경색을 완전히 투명하게 설정합니다.
        
        w.level = .floating
        w.isMovableByWindowBackground = false
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.isReleasedWhenClosed = false
        if let sttWindow = windowManager.sttWindow {
          sttWindow.addChildWindow(w, ordered: .above)
          
          w.parent = sttWindow
        }
        
        w.contentView?.autoresizesSubviews = true
        w.setContentSize(w.contentView!.bounds.size)
      }
    }
    return v
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    if let w = nsView.window {
      w.setContentSize(w.contentView!.bounds.size)
    }
  }
}
