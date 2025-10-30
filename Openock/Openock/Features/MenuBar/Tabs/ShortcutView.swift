//
//  ShortcutView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct ShortcutView: View {
  // MARK: - State
  @State private var isShortcutEnabled: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("단축키")
        .font(.system(size: 11))
        .fontWeight(.medium)

      Form {
        Section {
          HStack(spacing: 12) {
            Text("실시간 자막 스크립트화 시작")
              .font(.system(size: 13, weight: .regular))

            Spacer()

            HStack(spacing: 6) {
              HStack(spacing: 2) {
                Image(systemName: "fn")
                  .font(.system(size: 12, weight: .semibold))
                Image(systemName: "command")
                  .font(.system(size: 12, weight: .semibold))
                Text("K")
                  .font(.system(size: 12, weight: .semibold, design: .monospaced))
              }

              Toggle("", isOn: $isShortcutEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
            }
          }
        }
      }
      .formStyle(.grouped)
      .padding(.horizontal, -24)
      .padding(.vertical, -24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  ShortcutView()
}
