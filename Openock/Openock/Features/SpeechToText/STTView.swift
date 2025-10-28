//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI
import AppKit

struct STTView: View {
  @EnvironmentObject var sttEngine: STTEngine
  @EnvironmentObject var appDelegate: AppDelegate
  @State private var showRecordOnly: Bool = false
  @State private var showControls: Bool = true
  @State private var hideTimer: Timer?
  @State private var window: NSWindow?
  
  @State private var previousFrame: NSRect?
  @State private var anchorTop: CGFloat?
  @State private var isAdjusting = false
  
  // 자막 수 제한
  private var transcriptLineCount: Int {
    max(1, sttEngine.transcript.split(separator: "\n").count)
  }
  private let minLineHeight: CGFloat = 32
  private let maxTranscriptHeight: CGFloat = 200
  
  
  var body: some View {
    ZStack(alignment: .top) {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if sttEngine.transcript.isEmpty {
            VStack(alignment: .center, spacing: 10) {
              Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.5))
              Text("음성이 인식되면 여기에 표시됩니다...")
                .foregroundStyle(.gray)
                .italic()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
          } else {
            Text(sttEngine.transcript)
              .textSelection(.enabled)
              .font(.title)
              .lineSpacing(4)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }
      .padding(.top, 48)
      .padding(.horizontal, 8)
      .frame(
        minHeight: minLineHeight * CGFloat(transcriptLineCount) + 48,
        maxHeight: maxTranscriptHeight + 48
      )
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.ultraThinMaterial)
      )
      .background(
        Color.clear
          .glassEffect(.clear, in: .rect)
      )
      if showControls {
        HStack(alignment: .center, spacing: 0) {
          HStack {
            if sttEngine.isPaused {
              Text("일시정지")
                .foregroundStyle(.white)
                .font(Font.custom("SF Pro", size: 18))
            }
          }
          .padding(.horizontal, 16)
          .frame(maxWidth: .infinity, alignment: .leading)
          
          HStack(alignment: .center) {
            Button(action: {
              if sttEngine.isRecording {
                sttEngine.isPaused ? sttEngine.resumeRecording() : sttEngine.pauseRecording()
              }
            }) {
              Image(sttEngine.isPaused ? "play_icon" : "pause_icon")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.white)
            .disabled(!sttEngine.isRecording)
            Button {
              if sttEngine.isRecording {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                  showRecordOnly.toggle()
                }
              }
            } label: {
              Image(showRecordOnly ? "doc_icon_active" : "doc_icon")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.white)
            .disabled(!sttEngine.isRecording)
          }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.clear)//ultraThinMaterial)
        )
        .padding(.horizontal, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .zIndex(1)
      }
    }
    .onHover{isHovering in
      if isHovering {
        showControlsTemporarily()
      } else {
        startHideTimer()
      }
    }
    .onTapGesture {
      showControlsTemporarily()
    }
    .onChange(of: appDelegate.windowDidBecomeKey) {
      if appDelegate.windowDidBecomeKey {
        showControlsTemporarily()
        DispatchQueue.main.async {
          appDelegate.windowDidBecomeKey = false
        }
      }
    }
    .onAppear {
      sttEngine.setupSystemCapture{success in
        if success {
          sttEngine.startRecording()
        } else {
          print("Error")
        }
      }
    }
    .onDisappear{
      hideTimer?.invalidate()
      hideTimer = nil
    }
    .background(
      WindowAccessor { win in
        self.window = win
        if self.previousFrame == nil, let w = win {
          self.previousFrame = w.frame
          w.titleVisibility = .hidden
          w.titlebarAppearsTransparent = true
          w.styleMask.insert(.fullSizeContentView)
          w.titlebarSeparatorStyle = .none
          w.toolbar = nil
          w.isMovableByWindowBackground = true
        }
      }
    )
  }
  private func showControlsTemporarily() {
    if showControls {
      hideTimer?.invalidate()
      startHideTimer()
      return
    }
    withAnimation(.easeInOut(duration: 0.2)) {
      showControls = true
    }
    setTrafficLights(visible: true)
    hideTimer?.invalidate()
    startHideTimer()
  }
  private func startHideTimer() {
    hideTimer?.invalidate()
    hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      if self.showControls {
        withAnimation(.easeInOut(duration: 0.2)) {
          self.showControls = false
        }
      }
      self.setTrafficLights(visible: false)
    }
  }
  private func setTrafficLights(visible: Bool) {
    guard let w = window else { return }
    let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    for t in types {
      if let btn = w.standardWindowButton(t) {
        btn.isHidden = !visible
      }
    }
  }
}
struct WindowAccessor: NSViewRepresentable {
  var onResolve: (NSWindow?) -> Void
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      onResolve(view.window)
    }
    return view
  }
  func updateNSView(_ nsView: NSView, context: Context) {
    //DispatchQueue.main.async { onResolve(nsView.window)}
  }
}

#Preview {
  STTView()
    .environmentObject(STTEngine())
}
