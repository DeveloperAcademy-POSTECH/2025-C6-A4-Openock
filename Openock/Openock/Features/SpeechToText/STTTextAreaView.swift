import SwiftUI

/// STT 뷰의 텍스트 표시 영역
struct STTTextAreaView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager

  let lineSpacing: CGFloat
  let onTap: () -> Void

  var body: some View {
    Group {
      if pipeline.transcript.isEmpty {
        VStack(alignment: .center, spacing: 18) {
          Image(systemName: "text.aligncenter")
            .font(.system(size: 52))
            .foregroundStyle(Color.bsGrayScale2)
          Text("음성을 감지하면 자막이 표시됩니다.")
            .font(.bsCaption1)
            .lineHeight(1.5, fontSize: 24)
            .foregroundStyle(Color.bsGrayScale2)
        }
        .frame(maxWidth: .infinity)
      } else {
        ScrollViewReader { proxy in
          ScrollView(.vertical) {
            VStack(alignment: .center, spacing: 0) {
              Spacer(minLength: 0)

              SubtitleFXView(
                text: pipeline.transcript,
                baseFontName: settings.selectedFont,
                baseFontSize: settings.fontSize,
                baseColor: settings.textColor,
                style: pipeline.fxStyle,
                lineSpacing: lineSpacing,
                textAlignment: .center
              )
              .frame(maxWidth: .infinity)
              .fixedSize(horizontal: false, vertical: true)
              .id("BOTTOM")
            }
            .clipped()
          }
          .onChange(of: pipeline.transcript) {_ in
            withAnimation(.easeOut(duration: 0.1)) {
              proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }
}
