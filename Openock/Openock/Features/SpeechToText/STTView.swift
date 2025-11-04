//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

struct STTView: View {
  @EnvironmentObject var sttEngine: STTEngine
  @EnvironmentObject var settings: SettingsManager
  @State private var isExpanded = false

  private let lineSpacing: CGFloat = 4

  private func toggleWindowHeight() {
    guard let window = NSApp.keyWindow else { return }

    let currentFrame = window.frame
    let newHeight: CGFloat

    if isExpanded {
      // Collapse to half
      newHeight = currentFrame.height / 2
    } else {
      // Expand to double
      newHeight = currentFrame.height * 2
    }

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
      
      VStack {
        HStack {
          Spacer()
          if sttEngine.isRecording {
            if sttEngine.isPaused {
              Button(action: { sttEngine.resumeRecording() }) {
                Image(systemName: "play.circle.fill")
                  .font(.system(size: 28))
              }
              .buttonStyle(.borderless)
              .tint(.green)
            } else {
              Button(action: { sttEngine.pauseRecording() }) {
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
        // Transcript display - starts from bottom
        if sttEngine.transcript.isEmpty {
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
              Text(sttEngine.transcript)
                .textSelection(.enabled)
                .font(Font.custom(settings.selectedFont, size: settings.fontSize))
                .foregroundStyle(settings.textColor)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .clipped()
            .onAppear {
              sttEngine.setupSystemCapture { success in
                if success {
                  sttEngine.startRecording()
                } else {
                  print("Error")
                }
              }
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
      sttEngine.setupSystemCapture { success in
        if success {
          sttEngine.startRecording()
        } else {
          print("Error")
        }
      }
    }
  }
}

#Preview {
  STTView()
    .environmentObject(STTEngine())
    .environmentObject(SettingsManager())
}
