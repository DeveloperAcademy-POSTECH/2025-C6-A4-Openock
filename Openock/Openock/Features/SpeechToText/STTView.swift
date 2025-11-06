import SwiftUI
import AVFoundation

struct STTView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager
  @State private var isExpanded = false

  private let lineSpacing: CGFloat = 4

  private func toggleWindowHeight() {
    guard let window = NSApp.keyWindow else { return }

    let currentFrame = window.frame
    let newHeight: CGFloat = isExpanded ? (currentFrame.height / 2) : (currentFrame.height * 2)

    // Keep the bottom position fixed, expand upward
    let newFrame = NSRect(
      x: currentFrame.origin.x,
      y: currentFrame.origin.y,
      width: currentFrame.width,
      height: newHeight
    )

    window.setFrame(newFrame, display: true, animate: true)
    isExpanded.toggle()
  }

  var body: some View {
    ZStack {
      settings.backgroundColor
        .id(settings.selectedBackground)
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: settings.selectedBackground)

      VStack(spacing: 0) {
        // 상단 컨트롤 (녹음/일시정지)
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
        .padding(.top, 10)

        // ✅ YAMNet 상태 한 줄 (HEAD에 추가 반영)
        Text(pipeline.yamStatus)
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal, 16)
          .frame(maxWidth: .infinity, alignment: .leading)

        // Transcript display - starts from bottom (HEAD 레이아웃 유지)
        if pipeline.transcript.isEmpty {
          Spacer()
          VStack(alignment: .center, spacing: 10) {
            Image(systemName: "text.bubble")
              .font(.system(size: 40))
              .foregroundColor(.gray.opacity(0.5))
            Text("음성이 인식되면 여기에 표시됩니다...")
              .foregroundColor(.gray)
              .italic()
          }
          .frame(maxWidth: .infinity)
          .padding(.bottom, 20)
        } else {
          GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
              Spacer(minLength: 0)
              Text(pipeline.transcript)
                .font(Font.custom(settings.selectedFont, size: settings.fontSize))
                .foregroundStyle(settings.textColor)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .clipped()
          }
          .padding()
          .padding(.bottom, 20)
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
      toggleWindowHeight()
    }
    .onAppear {
      // ✅ 파이프라인 시작 (캡처 → YAM → STT)
      pipeline.startRecording()
    }
  }
}

#Preview {
  STTView()
    .environmentObject(AudioPipeline())
    .environmentObject(SettingsManager())
}
