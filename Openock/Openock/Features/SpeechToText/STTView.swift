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

  // 트래픽 라이트 버튼 자동 숨김을 위한 상태 추가
  @State private var trafficLightHideTimer: Timer?
  @State private var mouseMoveMonitor: Any?
  @State private var mouseMoveLocalMonitor: Any?
  @State private var lastMouseMoveTime = Date()
  @State private var isTrafficLightsHidden = false  // 타이틀바 숨김 상태 추적
  @State private var titlebarOverlayView: NSView?  // 타이틀바 오버레이 뷰
  
  private let lineSpacing: CGFloat = 4

  
  //트래픽 라이트 버튼 숨김/표시 함수
  private func hideTrafficLights() {
    guard let w = window else { return }
    let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    buttons.forEach { buttonType in
      if let button = w.standardWindowButton(buttonType) {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.allowsImplicitAnimation = true
          button.animator().alphaValue = 0.0
        }
      }
    }
    // 타이틀바 영역도 함께 숨기기
    isTrafficLightsHidden = true
    showTitlebarOverlay()
  }
  
  private func showTrafficLights() {
    guard let w = window else { return }
    let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    buttons.forEach { buttonType in
      if let button = w.standardWindowButton(buttonType) {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.allowsImplicitAnimation = true
          button.animator().alphaValue = 1.0
        }
      }
    }
    // 타이틀바 영역 다시 표시
    isTrafficLightsHidden = false
    hideTitlebarOverlay()
  }
  
  //타이틀바 영역을 투명하게 덮는 오버레이 표시
  private func showTitlebarOverlay() {
    guard let w = window, let contentView = w.contentView else { return }
    
    // 기존 오버레이 제거
    hideTitlebarOverlay()
    
    // 타이틀바 높이
    let titlebarHeight: CGFloat = 28
    
    // contentView의 bounds 기준으로 타이틀바 영역 계산
    let contentBounds = contentView.bounds
    let titlebarRect = NSRect(
      x: 0,
      y: contentBounds.height - titlebarHeight,
      width: contentBounds.width,
      height: titlebarHeight
    )
    
    // 투명한 오버레이 뷰 생성
    let overlayView = NSView(frame: titlebarRect)
    overlayView.wantsLayer = true
    
    // 배경색과 동일하게 설정하여 타이틀바 영역 전체를 덮음
    let backgroundColor = NSColor(settings.backgroundColor)
    overlayView.layer?.backgroundColor = backgroundColor.withAlphaComponent(0.8).cgColor
    overlayView.autoresizingMask = [.width, .minYMargin]
    
    // 윈도우의 contentView에 추가 (상단에 배치)
    contentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
    titlebarOverlayView = overlayView
      
    // 애니메이션으로 페이드인
    overlayView.alphaValue = 0.0
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.3
      overlayView.animator().alphaValue = 1.0
    }
  }
  
  //타이틀바 오버레이 제거
  private func hideTitlebarOverlay() {
    guard let overlayView = titlebarOverlayView else { return }
    
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.3
      overlayView.animator().alphaValue = 0.0
    } completionHandler: {
      overlayView.removeFromSuperview()
      self.titlebarOverlayView = nil
    }
  }
  
  //마우스 움직임 감지 및 타이머 관리
  private func setupTrafficLightAutoHide() {
    // 기존 모니터 제거
    if let monitor = mouseMoveMonitor {
      NSEvent.removeMonitor(monitor)
      mouseMoveMonitor = nil
    }
    if let local = mouseMoveLocalMonitor {
      NSEvent.removeMonitor(local)
      mouseMoveLocalMonitor = nil
    }
    
    // 마우스 움직임 모니터 추가 (Global)
    mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
      self.lastMouseMoveTime = Date()
      
      // 버튼이 숨겨져 있으면 다시 표시
      if let w = self.window,
         let closeButton = w.standardWindowButton(.closeButton),
         closeButton.alphaValue < 0.5 {
        self.showTrafficLights()
      }
      
      // 타이머 리셋
      self.trafficLightHideTimer?.invalidate()
      self.startTrafficLightHideTimer()
    }
    
    // 윈도우 내부 마우스 움직임도 감지 (Local)
    let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
      self.lastMouseMoveTime = Date()
      
      if let w = self.window,
         let closeButton = w.standardWindowButton(.closeButton),
         closeButton.alphaValue < 0.5 {
        self.showTrafficLights()
      }
      
      self.trafficLightHideTimer?.invalidate()
      self.startTrafficLightHideTimer()
      return event
    }
    mouseMoveLocalMonitor = localMonitor
    
    // 초기 타이머 시작
    startTrafficLightHideTimer()
  }
  
  private func startTrafficLightHideTimer() {
    trafficLightHideTimer?.invalidate()
    // 3초 후 숨김 (원하는 시간으로 조절 가능)
    trafficLightHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      self.hideTrafficLights()
    }
  }
  
  private func cleanupTrafficLightAutoHide() {
    trafficLightHideTimer?.invalidate()
    trafficLightHideTimer = nil
    
    if let monitor = mouseMoveMonitor {
      NSEvent.removeMonitor(monitor)
      mouseMoveMonitor = nil
    }
    if let local = mouseMoveLocalMonitor {
      NSEvent.removeMonitor(local)
      mouseMoveLocalMonitor = nil
    }
  }
  
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
      let bottomPadding: CGFloat = 16
      
      // ⭐️ 텍스트 영역이 표시될 때 필요한 '최대' 높이를 기준으로 항상 계산합니다.
      let requiredTextHeight = baseTextAreaHeight()
      
      let titlebarHeight: CGFloat = isTrafficLightsHidden ? 0 : 28
    
      // 이제 텍스트 영역의 표시 여부와 상관없이 항상 최대 필요 높이를 반환합니다.
      return max(requiredTextHeight + bottomPadding, 1)
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
        if textVisible {
          STTTextAreaView(
            lineSpacing: lineSpacing
          )
          .environmentObject(pipeline)
          .environmentObject(settings)
        }
      }
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .frame(maxHeight: .infinity, alignment: .top)
        
      VStack {
        Spacer()
        HStack {
          Spacer()
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
          .padding(.trailing, 16)
          .padding([.top, .bottom], 12)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())

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
    }
    // ✅ (HEAD 의도) YAMCue 구독 — 오버레이 트리거
    .onReceive(pipeline.$yamCue.compactMap { $0 }) { cue in
      presentOverlay(for: cue, total: 3.0)
    }
    .onDisappear {
      textHideTimer?.invalidate(); textHideTimer = nil
      hoverStateTimer?.invalidate(); hoverStateTimer = nil
      
      cleanupTrafficLightAutoHide()
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
          //윈도우가 설정된 후 트래픽 라이트 자동 숨김 설정
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupTrafficLightAutoHide()
          }
        }
      }
    )
    .onChange(of: window?.frame) { _, _ in
      // 윈도우 크기 변경 시 오버레이 위치와 크기 업데이트
      if isTrafficLightsHidden, let overlayView = titlebarOverlayView, let w = window, let contentView = w.contentView {
        let titlebarHeight: CGFloat = 28
        let contentBounds = contentView.bounds
        overlayView.frame = NSRect(
          x: 0,
          y: contentBounds.height - titlebarHeight,
          width: contentBounds.width,
          height: titlebarHeight
        )
      }
    }
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
