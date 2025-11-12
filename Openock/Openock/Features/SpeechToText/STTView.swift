//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//
import SwiftUI
import AVFoundation
import AppKit   // ✅ NSWindow 등 AppKit 타입 사용

struct STTView: View {
  @EnvironmentObject var pipeline: AudioPipeline
  @EnvironmentObject var settings: SettingsManager
  @EnvironmentObject var appDelegate: AppDelegate

  @State private var window: NSWindow?
  @State private var showTextArea = true
  @State private var textHideTimer: Timer?
  @State private var isHovering = false
  @State private var lastHeightUpdate = Date.distantPast
  @State private var resizeDelegate = WindowResizeDelegate()
  @State private var titlebarColorView: NSView?
  @State private var hoverStateTimer: Timer?

  private let lineSpacing: CGFloat = 4
  private let controlHeight: CGFloat = 50

  // MARK: - Height helpers
  private func baseTextAreaHeight() -> CGFloat {
    let fontName = settings.selectedFont
    let fontSize = CGFloat(settings.fontSize)
    let font = NSFont(name: fontName, size: fontSize + 24) ?? NSFont.systemFont(ofSize: fontSize + 24)
    let lineHeight = ceil(font.ascender - font.descender + font.leading)
    let textHeight = (lineHeight * 2) + lineSpacing + 24
    return max(textHeight, 50)
  }

  private func totalWindowHeight() -> CGFloat {
    let controlsVisible = pipeline.isPaused || isHovering
    let textVisible = pipeline.isPaused ? showTextArea : true
    var height: CGFloat = 0
    if controlsVisible { height += controlHeight }
    if textVisible { height += baseTextAreaHeight() }
    if !controlsVisible && !textVisible { height = 1 }
    return height
  }

  private func updateWindowHeight() {
    guard let w = window else { return }
    let desiredContentHeight = max(totalWindowHeight(), 1)
    let currentFrame = w.frame
    let currentContentRect = w.contentRect(forFrameRect: currentFrame)
    let targetContentSize = NSSize(width: currentContentRect.width, height: desiredContentHeight)

    w.contentMinSize = NSSize(width: 200, height: 1)
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
    let controlsVisible = pipeline.isPaused || isHovering
    let textVisible = pipeline.isPaused ? showTextArea : true

    ZStack(alignment: .top) {
      settings.backgroundColor
        .opacity(0.8)
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea(.all)

      VStack(spacing: 0) {
        if controlsVisible {
          STTControlsView(controlHeight: controlHeight)
            .environmentObject(pipeline)
            .environmentObject(settings)
        }
        if textVisible {
          STTTextAreaView(
            lineSpacing: lineSpacing,
            height: baseTextAreaHeight(),
            onTap: updateWindowHeight
          )
          .environmentObject(pipeline)
          .environmentObject(settings)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())

    // Hover show/hide controls
    .onHover { hovering in
      if hovering {
        hoverStateTimer?.invalidate()
        isHovering = true
        if !pipeline.isPaused { throttledUpdateWindowHeight() }
      } else {
        hoverStateTimer?.invalidate()
        hoverStateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
          self.isHovering = false
          if !pipeline.isPaused { throttledUpdateWindowHeight() }
        }
      }
    }

    // ✅ New API: two-parameter closure
    .onChange(of: appDelegate.windowDidBecomeKey) { _, newValue in
      if newValue {
        throttledUpdateWindowHeight()
        DispatchQueue.main.async { appDelegate.windowDidBecomeKey = false }
      }
    }

    // ✅ New API: two-parameter closure for isPaused
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
    }

    // ✅ New API: two-parameter closure (값은 필요 없지만 경고 제거)
    .onChange(of: settings.fontSize) { _, _ in
      throttledUpdateWindowHeight()
    }

    .onDisappear {
      textHideTimer?.invalidate(); textHideTimer = nil
      hoverStateTimer?.invalidate(); hoverStateTimer = nil
    }

    .background(
      WindowAccessor { win in
        self.window = win
        if let w = win {
          w.delegate = resizeDelegate
          w.applyLiquidGlass()
          w.level = .floating
          w.isMovableByWindowBackground = true
          w.toolbar = nil
          w.contentResizeIncrements = NSSize(width: 1, height: 1)
          w.contentMinSize = NSSize(width: 200, height: 1)
          w.contentMaxSize = NSSize(width: 10000, height: 10000)
          w.styleMask.insert(.resizable)
          w.resizeIncrements = NSSize(width: 1, height: 1)
          if let contentView = w.contentView {
            contentView.autoresizingMask = [.width]
            contentView.translatesAutoresizingMaskIntoConstraints = true
          }
        }
      }
    )
  }
}

#Preview {
  STTView()
    .environmentObject(AudioPipeline())
    .environmentObject(SettingsManager())
    .environmentObject(AppDelegate())
}
