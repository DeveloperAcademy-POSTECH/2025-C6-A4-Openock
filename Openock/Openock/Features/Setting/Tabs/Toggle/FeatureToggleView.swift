//  FeatureToggleView.swift
//  Openock
//
//  Created by enoch on 11/7/25.
//

import SwiftUI

enum HoveredFeature {
    case sizeFX
    case yamReactions
    case whistle
}

struct FeatureToggleView: View {
    @EnvironmentObject var settings: SettingsManager
    var onSelect: () -> Void = {}

    @State private var hoveredFeature: HoveredFeature?
    @State private var showStopImage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("추가 기능")
                .font(.bsTitle)
                .lineHeight(1.5, fontSize: 11)
                .foregroundColor(Color.bsGrayScale1)

            VStack(spacing: 4) {
                featureRow(
                    title: "자막 크기 및 색상 강조",
                    isOn: $settings.toggleSizeFX,
                    feature: .sizeFX
                )

                Divider()

                featureRow(
                    title: "자막 외 소리에 따른 화면 반응",
                    isOn: $settings.toggleYamReactions,
                    feature: .yamReactions
                )

                Divider()

                featureRow(
                    title: "호루라기 소리 알림",
                    isOn: $settings.toggleWhistle,
                    feature: .whistle
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

            previewArea
                .padding(.top, 7)
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bsTextBackgroundWhite)

            if let feature = hoveredFeature {
                if showStopImage && !shouldLoop(for: feature) {
                    Image(stopImageName(for: feature))
                        .resizable()
                        .scaledToFit()
                } else {
                    GIFView(
                        name: gifName(for: feature),
                        loops: shouldLoop(for: feature),
                        onFinished: {
                            withAnimation(nil) {
                                showStopImage = true
                            }
                        }
                    )
                }
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.bsGrayScale3, lineWidth: 0.5)
        )
    }

    private func gifName(for feature: HoveredFeature) -> String {
        switch feature {
        case .sizeFX:
            return "preview_sizeFX"
        case .yamReactions:
            return "preview_yamReactions"
        case .whistle:
            return "preview_whistle"
        }
    }

    private func stopImageName(for feature: HoveredFeature) -> String {
        switch feature {
        case .sizeFX:
            return "preview_sizeFX_stop"
        case .whistle:
            return "preview_whistle_stop"
        case .yamReactions:
            return ""
        }
    }

    private func shouldLoop(for feature: HoveredFeature) -> Bool {
        switch feature {
        case .sizeFX, .whistle:
            return false
        case .yamReactions:
            return true
        }
    }

    @ViewBuilder
    private func featureRow(title: String, isOn: Binding<Bool>, feature: HoveredFeature) -> some View {
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
        .onHover { isHovering in
            withAnimation(nil) {
                if isHovering {
                    showStopImage = false
                    hoveredFeature = feature
                } else {
                    hoveredFeature = nil
                }
            }
        }
    }
}
