//
//  OverlayTextView.swift
//  Openock
//
//  Created by ellllly on 11/12/25.
//

import SwiftUI
import Lottie

// 오버레이 표시용 SwiftUI 뷰 (함성/야유 애니메이션)
struct OverlayTextView: View {
  @State private var opacity: Double = 0.0
  
  let cue: YamCue
  let total: TimeInterval
  let onFinished: () -> Void

  var body: some View {
    ZStack {
      Color.clear.ignoresSafeArea()

      HStack {
         LottieView(name: cue == .cheer ? "cheer" : "boo", loopMode: .playOnce)
           .frame(maxWidth: .infinity, alignment: .leading)
           .padding(.vertical, 24)
           // .padding(.horizontal, 40)
           // .padding(.vertical, 24)

          Spacer()

         LottieView(name: cue == .cheer ? "cheer" : "boo", loopMode: .playOnce)
           .frame(maxWidth: .infinity, alignment: .trailing)
           .padding(.vertical, 24)
           // .padding(.horizontal, 40)
           // .padding(.vertical, 24)
       }
       .padding(.horizontal, 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .ignoresSafeArea()
    .task {
      if cue == .cheer {
        // 즉시 표시 → 서서히 사라짐
        opacity = 1.0
        withAnimation(.easeOut(duration: total)) { opacity = 0.0 }
        try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
      } else {
        // 야유: 반은 점점 진하게, 반은 점점 연하게
        let half = total / 2
        withAnimation(.easeIn(duration: half)) { opacity = 1.0 }
        try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))
        withAnimation(.easeOut(duration: half)) { opacity = 0.0 }
        try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))
      }
      onFinished()
    }
  }
}
