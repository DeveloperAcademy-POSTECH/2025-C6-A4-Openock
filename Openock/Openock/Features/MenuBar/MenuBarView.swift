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
//    case shortcut = "단축키"
  }

  @State private var tab: Tab = .appearance

  var body: some View {
    VStack(spacing: 0) {
      Header()
        .padding(.horizontal, 8)
      // 상단 탭
      Tabs(tab: $tab)
        .padding(.horizontal, 10)
      
      Divider()
        .padding(.top, 6)
        .padding(.bottom, 20)

      // 탭 컨텐츠
      HStack(spacing: 0) {
        Spacer().frame(width: 16) // left gutter (always visible)
        VStack(alignment: .leading, spacing: 0) {
          switch tab {
          case .appearance:
            AppearanceView(onSelect: {})
//          case .shortcut:
//            ShortcutView()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Spacer().frame(width: 16) // right gutter (always visible)
      }
      .frame(maxHeight: .infinity, alignment: .top)
      
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

//      HStack {
//        Spacer()
//        Image(systemName: "house")
//          .font(.system(size: 13))
//      }
    }
    .frame(height: 28)
  }
}



// MARK: - Tabs
private struct Tabs: View {
  @Binding var tab: MenuBarView.Tab

  var body: some View {
    HStack(spacing: 6) {
      ForEach(MenuBarView.Tab.allCases, id: \.self) { t in
        Button {
          tab = t
        } label: {
          Text(t.rawValue)
            .font(.system(size: 13, weight: tab == t ? .semibold : .regular))
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(tab == t ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
