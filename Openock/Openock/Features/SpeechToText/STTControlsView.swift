//
//  STTControlsView.swift
//  Openock
//
//  Created by JiJooMaeng on 11/10/25.
//

import SwiftUI

/// STT 뷰의 컨트롤 영역 (일시정지 텍스트, 일시정지/재생 버튼)
struct STTControlsView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager

  let controlHeight: CGFloat

  var body: some View {
    // ✅ SwiftUI가 Binding이 아닌 실제 객체로 인식하도록 명시
    let pipeline = pipeline

    HStack(alignment: .center, spacing: 0) {
      HStack {
        if pipeline.isPaused {
          Text("일시정지")
            .font(.bsCaption2)
            .lineHeight(1.5, fontSize: 24)
            .foregroundStyle(settings.textColor)
        }
      }
      .padding(.horizontal,12)
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(alignment: .center, spacing: 8) {
        Button(action: {
          if pipeline.isRecording {
            pipeline.isPaused ? pipeline.resumeRecording() : pipeline.pauseRecording()
          }
        }) {
          Image(pipeline.isPaused ? "play_on" : "play_off")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .foregroundColor(settings.textColor)
        }
        .buttonStyle(.plain)
        .disabled(!pipeline.isRecording)
      }
      .padding(.horizontal, 12)
    }
    .frame(height: controlHeight)
    .frame(maxWidth: .infinity)
    .allowsHitTesting(true)
    .zIndex(10)
  }
}
