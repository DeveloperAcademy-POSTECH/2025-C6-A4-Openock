//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

struct STTView: View {
  @StateObject private var sttRecorder = STTEngine()
  
  var body: some View {
    ZStack {
      Color.clear
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea()
      
      VStack {
        HStack {
          Spacer()
          if sttRecorder.isRecording {
            if sttRecorder.isPaused {
              Button(action: { sttRecorder.resumeRecording() }) {
                Image(systemName: "play.circle.fill")
                  .font(.system(size: 28))
              }
              .buttonStyle(.borderless)
              .tint(.green)
            } else {
              Button(action: { sttRecorder.pauseRecording() }) {
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
            if sttRecorder.transcript.isEmpty {
              VStack(alignment: .center, spacing: 10) {
                Image(systemName: "text.bubble")
                  .font(.system(size: 40))
                  .foregroundColor(.gray.opacity(0.5))
                Text("음성이 인식되면 여기에 표시됩니다...")
                  .foregroundColor(.gray)
                  .italic()
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 40)
            } else {
              Text(sttRecorder.transcript)
                .textSelection(.enabled)
                .font(.title)
                .lineSpacing(4)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .onAppear {
            sttRecorder.setupSystemCapture { success in
              if success {
                sttRecorder.startRecording()
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
}
