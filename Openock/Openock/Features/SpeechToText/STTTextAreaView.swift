import SwiftUI

/// STT 뷰의 텍스트 표시 영역
struct STTTextAreaView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager

  let lineSpacing: CGFloat
  let height: CGFloat
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        GeometryReader { geo in
          VStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 0)

            // ✅ 증가분 tail 스타일을 영구 적용하는 FX 렌더링
            SubtitleFXView(
              text: pipeline.transcript,
              baseFontName: settings.selectedFont,
              baseFontSize: settings.fontSize,
              baseColor: settings.textColor,
              style: pipeline.fxStyle,          // FXEngine이 제공하는 현재 tail 스타일
              lineSpacing: lineSpacing,
              textAlignment: .center             // 기존 UI와 동일하게 가운데 정렬
            )
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
          }
          .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
          .clipped()
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(height: height)
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }
}
