//  FeatureToggleView.swift
//  Openock
//
//  Created by enoch on 11/7/25.
//

import SwiftUI

struct FeatureToggleView: View {
  // ✅ SettingsManager를 Environment에서 받아서 실제 앱 설정과 연결
  @EnvironmentObject var settings: SettingsManager
  var onSelect: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("추가 기능")
        .font(.bsTitle)
        .lineHeight(1.5, fontSize: 11)
        .foregroundColor(Color.bsGrayScale1)
        .padding(.horizontal, 16)

      VStack(spacing: 0) {
        featureRow(
          title: "자막 크기 효과",
          isOn: $settings.toggleSizeFX
        )

        Divider().padding(.leading, 16)

        featureRow(
          title: "자막 외 소리에 따른 화면 반응",
          isOn: $settings.toggleYamReactions
        )

        Divider().padding(.leading, 16)

        featureRow(
          title: "호루라기 소리 알림",
          isOn: $settings.toggleWhistle
        )
      }
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.bsGrayScale5)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.bsGrayScale4, lineWidth: 0.5)
      )
    }
  }

  @ViewBuilder
  private func featureRow(title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .font(.bsToggleCaption)
        .lineHeight(1.2, fontSize: 13)
        .foregroundColor(Color.bsTextBackgroundBlack)
        .padding(.vertical, 10)
      Spacer()
      Toggle("", isOn: isOn)
        .toggleStyle(.switch)
        .labelsHidden()
    }
    .padding(.horizontal, 16)
  }
}
