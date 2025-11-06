import SwiftUI
import AVFoundation
import AppKit
import Combine

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
    // 여기 3.0 수정하면 더 길게 줄 수 있음
    .onReceive(pipeline.$yamCue.compactMap { $0 }) { cue in
      presentOverlay(for: cue, total: 3.0)
    }
  }
}

#Preview {
  STTView()
    .environmentObject(AudioPipeline())
    .environmentObject(SettingsManager())
}

// MARK: - ===== Overlay Helpers (병합 쉬우도록 함수화) =====

private func presentOverlay(for cue: YamCue, total: TimeInterval) {
  OverlayController.shared.present(cue: cue, total: total)
}

/// 오버레이 윈도우 생성
private func makeOverlayWindows(for cue: YamCue, total: TimeInterval, onFinish: @escaping () -> Void) -> [NSWindow] {
  NSScreen.screens.map { screen in
    let win = NSWindow(
      contentRect: screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    win.level = .screenSaver
    win.isOpaque = false
    win.backgroundColor = .clear
    win.ignoresMouseEvents = true
    win.hasShadow = false
    win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    win.setFrame(screen.frame, display: true)

    let host = NSHostingView(rootView: OverlayTextView(cue: cue, total: total) {
      onFinish()
    })
    host.frame = win.contentRect(forFrameRect: screen.frame)
    host.autoresizingMask = [.width, .height]
    win.contentView = host
    return win
  }
}

/// 오버레이 윈도우 제거
private func tearDownOverlays(_ windows: inout [NSWindow]) {
  windows.forEach { $0.orderOut(nil) }
  windows.removeAll()
}

/// 진행 상태/수명 관리
private final class OverlayController {
  static let shared = OverlayController()
  private init() {}

  private var windows: [NSWindow] = []
  private var animating: Bool = false

  func present(cue: YamCue, total: TimeInterval) {
    guard !animating else { return }      // 진행 중엔 무시
    animating = true

    tearDownOverlays(&windows)
    windows = makeOverlayWindows(for: cue, total: total) { [weak self] in
      guard let self else { return }
      tearDownOverlays(&self.windows)
      self.animating = false
    }
    windows.forEach { $0.orderFrontRegardless() }
  }
}

// 오버레이 표시용 SwiftUI 뷰 (함성/야유 애니메이션)
private struct OverlayTextView: View {
  let cue: YamCue
  let total: TimeInterval
  let onFinished: () -> Void

  @State private var opacity: Double = 0.0

  var body: some View {
    ZStack {
      Color.clear.ignoresSafeArea()

      Text(cue == .cheer ? "함성!" : "야유…")
        .font(.system(size: cue == .cheer ? 120 : 110, weight: .black))
        .foregroundColor(.white)
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .background(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(backgroundColor.opacity(0.85))
        )
        .shadow(radius: 30)
        .opacity(opacity)
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

  private var backgroundColor: Color {
    switch cue {
    case .cheer: return .accentColor
    case .boo:   return .black
    }
  }
}
