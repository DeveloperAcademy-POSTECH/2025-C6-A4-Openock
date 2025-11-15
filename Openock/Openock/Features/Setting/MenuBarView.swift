//
//  MenuBarView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject var settings: SettingsManager
  
  enum Tab: String, CaseIterable {
    case appearance = "배경 및 글씨"
    case featureToggle = "기능 온오프"
  }

  @State private var tab: Tab = .appearance
  @State private var showFontPicker: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Header()
        .background(Color.bsSettingsTitleBackground)
      
      // MARK: - 상단 탭
      Tabs(tab: $tab)
        .background(Color.bsSettingsTitleBackground)
      
      Rectangle()
        .frame(height: 0.67)
        .foregroundStyle(Color.bsGrayScale4)
        .padding(.vertical, 4)
        .ignoresSafeArea()
      
      // MARK: - 탭 컨텐츠
      VStack(alignment: .leading, spacing: 0) {
        switch tab {
        case .appearance:
          AppearanceView()
          .environmentObject(settings)
        case .featureToggle:
          FeatureToggleView(onSelect: {})
        }
      }
      .safeAreaPadding(16)
      
    }
    .frame(width: 346)
    .background(Color.bsTextBackgroundWhite)
  }
}

// MARK: - Header
private struct Header: View {
  var body: some View {
    ZStack {
      Text("설정")
        .font(.bsTitle)
        .lineHeight(1.5, fontSize: 11)
        .foregroundStyle(Color.bsTextBackgroundBlack)

      HStack {
        Spacer()
        Button(action: {
          if let url = URL(string: "https://posacademy.notion.site/Openock-2ab2b843d5af808db88af411ee6c9807?source=copy_link") {
            NSWorkspace.shared.open(url)
          }
        }, label: {
          Image(systemName: "link")
            .font(.system(size: 14))
            .foregroundStyle(Color.bsTextBackgroundBlack)
        })
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 5.37)
    .safeAreaPadding(.horizontal, 8.05)
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
            .font(tab == t ? .bsTabBarOn : .bsTabBarOff)
            .lineHeight(1.5, fontSize: 13)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(tab == t ? AnyShapeStyle(Color.bsGrayScale4) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
    .safeAreaPadding(.horizontal, 10.74)
    .padding(.vertical, 4)
  }
}

#Preview {
  MenuBarView()
    .environmentObject(SettingsManager())
}
