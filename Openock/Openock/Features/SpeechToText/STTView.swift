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
        
        // Transcript display
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            if sttEngine.transcript.isEmpty {
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
              Text(sttEngine.transcript)
                .textSelection(.enabled)
                .font(Font.custom(settings.selectedFont, size: settings.fontSize))
                .foregroundStyle(settings.textColor)
                .lineSpacing(4)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
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
    .environmentObject(STTEngine())
    .environmentObject(SettingsManager())
}
