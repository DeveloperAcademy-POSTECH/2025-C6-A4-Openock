//
//  FeatureToggleView.swift
//  Openock
//
//  Created by enoch on 11/7/25.
//

import SwiftUI

struct FeatureToggleView: View {
  var onSelect: () -> Void = {}
  
  @State private var isSubtitleEffectOn = true
  @State private var isScreenReactionOn = true
  @State private var isWhistleAlertOn = true
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("추가 기능")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
      
      VStack(spacing: 0) {
        featureRow(title: "자막 크기 효과", isOn: $isSubtitleEffectOn)
        
        Divider()
          .padding(.leading, 16)
        
        featureRow(title: "자막 외 소리에 따른 화면 반응", isOn: $isScreenReactionOn)
        
        Divider()
          .padding(.leading, 16)
        
        featureRow(title: "호루라기 소리 알림", isOn: $isWhistleAlertOn)
      }
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(NSColor.controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.gray.opacity(0.2))
      )
    }
  }
  
  @ViewBuilder
  private func featureRow(title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .foregroundColor(.primary)
        .padding(.vertical, 10)
      Spacer()
      Toggle("", isOn: isOn)
        .toggleStyle(.switch)
      .labelsHidden()
    }
    .padding(.horizontal, 16)
  }
}
