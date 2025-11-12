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
        VStack(alignment: .center, spacing: 10) {
          Image(systemName: "text.bubble")
            .font(.system(size: 40))
            .foregroundColor(.gray.opacity(0.5))
          Text("음성이 인식되면 여기에 표시됩니다...")
            .foregroundColor(.gray)
            .italic()
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
