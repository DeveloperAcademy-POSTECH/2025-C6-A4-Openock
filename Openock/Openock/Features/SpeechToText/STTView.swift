//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI
import AVFoundation
import AppKit        // ✅ NSWindow 등 AppKit 타입 사용
import Combine       // ✅ Combine도 유지 (YAMCue 구독용)

struct STTView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager
  @EnvironmentObject var appDelegate: AppDelegate

  @State private var window: NSWindow?
  @State private var showTextArea = true
  @State private var textHideTimer: Timer?
  @State private var isHovering = false
  @State private var lastHeightUpdate = Date.distantPast
  @State private var titlebarColorView: NSView?
  @State private var hoverStateTimer: Timer?
  @State private var keyEventMonitor: Any?

  private let lineSpacing: CGFloat = 4
  private let controlHeight: CGFloat = 50

  // MARK: - Height helpers
  private func baseTextAreaHeight() -> CGFloat {
    let fontName = settings.selectedFont
    let fontSize = CGFloat(settings.fontSize)
    
    let font = NSFont(name: fontName, size: fontSize + 24) ?? NSFont.systemFont(ofSize: fontSize + 24)
    // 3) 실제 줄 높이
    let lineHeight = ceil(font.ascender - font.descender + font.leading)
    let textHeight = (lineHeight * 2) + lineSpacing + 24

    return max(textHeight, 50)
  }
  private func totalWindowHeight() -> CGFloat {
      let controlsSpace: CGFloat = controlHeight // 50
      let bottomPadding: CGFloat = 16
      
      // ⭐️ 텍스트 영역이 표시될 때 필요한 '최대' 높이를 기준으로 항상 계산합니다.
      let requiredTextHeight = baseTextAreaHeight()
      
      // 이제 텍스트 영역의 표시 여부와 상관없이 항상 최대 필요 높이를 반환합니다.
      return max(controlsSpace + requiredTextHeight + bottomPadding, 1)
  }

  private func updateWindowHeight() {
    guard let w = window else { return }
    let desiredContentHeight = max(totalWindowHeight(), 1)
    let currentFrame = w.frame
    
    let currentContentRect = w.contentRect(forFrameRect: currentFrame)
    let targetContentSize = NSSize(width: currentContentRect.width, height: desiredContentHeight)

    w.contentMinSize = NSSize(width: 200, height: desiredContentHeight)
    w.contentMaxSize = NSSize(width: 10000, height: 10000)
    w.setContentSize(targetContentSize)
    w.contentMinSize = NSSize(width: 200, height: desiredContentHeight)
    w.contentMaxSize = NSSize(width: 10000, height: desiredContentHeight)
  }

  private func throttledUpdateWindowHeight(minInterval: TimeInterval = 0.05) {
    let now = Date()
    if now.timeIntervalSince(lastHeightUpdate) >= minInterval {
      lastHeightUpdate = now
      updateWindowHeight()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + minInterval) {
        updateWindowHeight()
        lastHeightUpdate = Date()
      }
    }
  }

  private func startTextHideTimer() {
    textHideTimer?.invalidate()
    textHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
      self.showTextArea = false
      self.updateWindowHeight()
    }
  }

  // MARK: - Body
  var body: some View {
    let textVisible = pipeline.isPaused ? showTextArea : true

    ZStack(alignment: .top) {
      settings.backgroundColor
        .opacity(0.8)
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea(.all)
      VStack(spacing: 0) {
        ZStack {
          STTControlsView(controlHeight: controlHeight)
            .opacity((isHovering || pipeline.isPaused) ? 1 : 0)
        }
        .frame(height: controlHeight)
      
        if textVisible {
          STTTextAreaView(
            lineSpacing: lineSpacing
          )
          .environmentObject(pipeline)
          .environmentObject(settings)
        }
        Spacer()
      }
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())

    // Hover show/hide controls
    .onHover { hovering in
      isHovering = hovering
    }

    // ✅ Swift 6: two-parameter closure (appDelegate)
    .onChange(of: appDelegate.windowDidBecomeKey) { _, newValue in
      if newValue {
        DispatchQueue.main.async { appDelegate.windowDidBecomeKey = false }
      }
    }

    // ✅ Swift 6: two-parameter closure (pipeline.isPaused)
    .onChange(of: pipeline.isPaused) { _, isPaused in
      if isPaused {
        textHideTimer?.invalidate()
        if !showTextArea { showTextArea = true }
        startTextHideTimer()
        throttledUpdateWindowHeight()
      } else {
        textHideTimer?.invalidate()
        if !showTextArea {
          withAnimation(.easeInOut(duration: 0.3)) { showTextArea = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          throttledUpdateWindowHeight()
        }
      }
    }

    .onAppear {
      // 파이프라인 시작 및 설정 바인딩
      pipeline.startRecording()
      pipeline.bindSettings(settings)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        throttledUpdateWindowHeight()
      }

      // 스페이스바 전역 모니터 설정
      keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.keyCode == 49 { // 49 = 스페이스바
          if pipeline.isRecording {
            if pipeline.isPaused {
              pipeline.resumeRecording()
            } else {
              pipeline.pauseRecording()
            }
          }
          return nil // 이벤트 소비
        }
        return event
      }
    }
    // ✅ (HEAD 의도) YAMCue 구독 — 오버레이 트리거
    .onReceive(pipeline.$yamCue.compactMap { $0 }) { cue in
      presentOverlay(for: cue, total: 3.0)
    }
    .onDisappear {
      textHideTimer?.invalidate(); textHideTimer = nil
      hoverStateTimer?.invalidate(); hoverStateTimer = nil

      // 키 이벤트 모니터 제거
      if let monitor = keyEventMonitor {
        NSEvent.removeMonitor(monitor)
        keyEventMonitor = nil
      }
    }
    .background(
      WindowAccessor { win in
        self.window = win
        if let w = win {
          w.applyLiquidGlass()
          w.level = .floating
          w.isMovableByWindowBackground = true
          w.toolbar = nil
          w.contentResizeIncrements = NSSize(width: 1, height: 1)
          w.styleMask.insert(.resizable)
          w.resizeIncrements = NSSize(width: 1, height: 1)

          if let contentView = w.contentView {
            contentView.autoresizingMask = [.width, .height]
            contentView.translatesAutoresizingMaskIntoConstraints = true
          }
        }
      }
    )
  }
}

// MARK: - Overlay 호출
private func presentOverlay(for cue: YamCue, total: TimeInterval) {
  OverlayController.shared.present(cue: cue, total: total)
}

#Preview {
  STTView()
    .environmentObject(AudioPipeline())
    .environmentObject(SettingsManager())
    .environmentObject(AppDelegate())
}
