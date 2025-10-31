//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

struct STTView: View {
  @EnvironmentObject var sttEngine: STTEngine
  
  // 자막 반응용 애니메이션 계수
  @State private var pulseScale: CGFloat = 1.0
  @State private var pulseOpacity: Double = 1.0
  
  var body: some View {
    ZStack {
      Color.clear
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea()
      
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
          VStack(alignment: .center, spacing: 10) {
            if sttEngine.transcript.isEmpty {
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
              // 🔹 Reactive Subtitle
              Text(sttEngine.transcript)
                .font(.title)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                // 🔹 오디오 레벨에 따라 크기와 투명도 변화
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                // 🔹 부드러운 애니메이션
                .animation(.easeOut(duration: 0.15), value: pulseScale)
//                .onChange(of: sttEngine.audioLevel) { level in
//                  // 오디오 레벨(0~1)에 따라 반응 범위 조절
//                  let targetScale = 1.0 + CGFloat(level) * 0.35
//                  let targetOpacity = 0.8 + Double(level) * 0.2
//                  
//                  pulseScale = targetScale
//                  pulseOpacity = targetOpacity
//                }
                // ✅ ADD: 저역(베이스) 레벨에만 반응하는 둠칫 효과
                .onChange(of: sttEngine.bassLevel) { bass in
                  let targetScale = 1.0 + CGFloat(bass) * 0.5
                  let targetOpacity = 0.85 + Double(bass) * 0.3
                  pulseScale = targetScale
                  pulseOpacity = targetOpacity
                }
            }
          }
          .frame(maxWidth: .infinity, alignment: .center)
          .onAppear {
            sttEngine.setupSystemCapture { success in
              if success {
                sttEngine.startRecording()
              } else {
                print("Error")
              }
            }
          }
          .padding(.horizontal)
          .padding(.top, 40)
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
}
