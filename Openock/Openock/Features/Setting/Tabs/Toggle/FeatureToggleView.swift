//  FeatureToggleView.swift
//  Openock
//
//  Created by enoch on 11/7/25.
//

import SwiftUI

struct FeatureToggleView: View {
  @EnvironmentObject var settings: SettingsManager
  var onSelect: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("추가 기능")
        .font(.bsTitle)
        .lineHeight(1.5, fontSize: 11)
        .foregroundColor(Color.bsGrayScale1)

      VStack(spacing: 4) {
        featureRow(
          title: "자막 크기 효과",
          isOn: $settings.toggleSizeFX
        )

        Divider()

        featureRow(
          title: "자막 외 소리에 따른 화면 반응",
          isOn: $settings.toggleYamReactions
        )

        Divider()

        featureRow(
          title: "호루라기 소리 알림",
          isOn: $settings.toggleWhistle
        )
      }
      .padding(.vertical, 8)
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
      Spacer()
      Toggle("", isOn: isOn)
        .toggleStyle(CustomSwitchToggleStyle(
          onColor: Color.bsMain,
          offColor: Color.bsGrayScale3,
          width: 23,
          height: 14,
          knobSize: 12
        ))
    }
    .padding(.horizontal, 8)
  }
}
