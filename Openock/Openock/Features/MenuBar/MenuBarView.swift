//
//  MenuBarView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct MenuBarView: View {
  enum Tab: String, CaseIterable {
    case appearance = "배경 및 글씨"
    case sound = "소리 알림"
    case shortcut = "단축키"
  }

  @State private var tab: Tab = .appearance

  // AppearanceView 상태
  @State private var fontChoice: AppearanceView.FontChoice = .sfPro
  @State private var fontSize: Double = 24
  @State private var captionBG: AppearanceView.CaptionBG = .black

  // SoundView 상태 (필요시 추가)
  // @State private var soundEnabled: Bool = true

  // ShortcutView 상태 (필요시 추가)
  // @State private var shortcutKey: String = ""

  var body: some View {
    VStack(spacing: 10) {
      Header()
        .padding(.horizontal, 14)
      // 상단 탭
      Tabs(tab: $tab)
        .padding(.horizontal, 14)

      // 탭 컨텐츠
      Group {
        switch tab {
        case .appearance:
          AppearanceView(
            fontChoice: $fontChoice,
            fontSize: $fontSize,
            captionBG: $captionBG
          )
        case .sound:
          SoundView()
        case .shortcut:
          ShortcutView()
        }
      }
      .frame(maxHeight: .infinity)
      .padding(.horizontal, 14)
    }
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    .environment(\.controlSize, .small)
    .frame(width: 346, height: 443)
  }
}

// MARK: - Header
private struct Header: View {
  var body: some View {
    ZStack {
      Text("설정")
        .font(.system(size: 11, weight: .semibold))
        .padding(.vertical, 4)

      HStack {
        Spacer()
        Image(systemName: "house")
          .font(.system(size: 13))
      }
    }
    .frame(height: 28)
  }
}



// MARK: - Tabs
private struct Tabs: View {
  @Binding var tab: MenuBarView.Tab

  var body: some View {
    HStack(spacing: 8) {
      ForEach(MenuBarView.Tab.allCases, id: \.self) { t in
        Button {
          tab = t
        } label: {
          Text(t.rawValue)
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(tab == t ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
  }
}

#Preview {
  MenuBarView()
}
