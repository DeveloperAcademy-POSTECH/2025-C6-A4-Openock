import SwiftUI
import AVFoundation

struct STTView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager

  var body: some View {
    ZStack {
      settings.backgroundColor
        .id(settings.selectedBackground)
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: settings.selectedBackground)

      VStack {
        HStack {
          Spacer()
          if pipeline.isRecording {
            if pipeline.isPaused {
              Button(action: { pipeline.resumeRecording() }) {
                Image(systemName: "play.circle.fill")
                  .font(.system(size: 28))
              }
              .buttonStyle(.borderless)
              .tint(.green)
            } else {
              Button(action: { pipeline.pauseRecording() }) {
                Image(systemName: "pause.circle.fill")
                  .font(.system(size: 28))
              }
              .buttonStyle(.borderless)
              .tint(.orange)
            }
          }
        }
        .padding(.trailing, 10)

        // ✅ YAMNet 상태 한 줄
        Text(pipeline.yamStatus)
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal, 16)
          .frame(maxWidth: .infinity, alignment: .leading)

        // Transcript
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            if pipeline.transcript.isEmpty {
              VStack(alignment: .center, spacing: 10) {
                Image(systemName: "text.bubble")
                  .font(.system(size: 40))
                  .foregroundColor(.gray.opacity(0.5))
                Text("음성이 인식되면 여기에 표시됩니다...")
                  .font(Font.custom(settings.selectedFont, size: settings.fontSize))
                  .foregroundColor(settings.textColor.opacity(0.7))
                  .italic()
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 40)
            } else {
              Text(pipeline.transcript)
                .textSelection(.enabled)
                .font(Font.custom(settings.selectedFont, size: settings.fontSize))
                .foregroundStyle(settings.textColor)
                .lineSpacing(4)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .onAppear {
            // ✅ 파이프라인 시작 (캡처 → YAM → STT)
            pipeline.startRecording()
          }
          .padding()
        }
        .cornerRadius(8)
        .padding()
        .frame(minHeight: 200)

        Spacer()
      }
    }
  }
}

#Preview {
  STTView()
    .environmentObject(AudioPipeline())
    .environmentObject(SettingsManager())
}
