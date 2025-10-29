//
//  SoundView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct SoundView: View {
  // 소리 알림 관련 상태들을 여기에 추가할 수 있습니다
  // 예: @Binding var isEnabled: Bool

  var body: some View {
    VStack {
      Spacer()
      Text("소리 알림")
        .font(.title3)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }
}

#Preview {
  SoundView()
}
