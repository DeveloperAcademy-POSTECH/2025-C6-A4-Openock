//
//  ShortcutView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct ShortcutView: View {
  // 단축키 관련 상태들을 여기에 추가할 수 있습니다
  // 예: @Binding var shortcutKey: String

  var body: some View {
    VStack {
      Spacer()
      Text("단축키")
        .font(.title3)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }
}

#Preview {
  ShortcutView()
}
