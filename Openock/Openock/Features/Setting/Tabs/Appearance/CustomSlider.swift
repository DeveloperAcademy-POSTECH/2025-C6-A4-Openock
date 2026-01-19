//
//  CustomSlider.swift
//  Openock
//
//  Created by enoch on 11/15/25.
//

import SwiftUI

struct CustomSlider: View {
  @Binding var value: CGFloat
  let steps: [CGFloat] = [18, 24, 32, 48, 64]
  
  let trackHeight: CGFloat = 0.67
  let thumbSize: CGFloat = 15
  
  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width

      ZStack(alignment: .leading) {

        // Track background
        Rectangle()
          .fill(Color.bsGrayScale2)
          .frame(height: trackHeight)

        // Step markers
        ZStack(alignment: .leading) {
          ForEach(steps.indices, id: \.self) { index in
            Circle()
              .fill(Color.bsGrayScale2)
              .frame(width: 2.53, height: 2.53)
              .offset(x: markerOffset(index: index, width: width))
          }
        }
        .frame(height: trackHeight)

        // Thumb + Label 묶음
        ZStack {
          Circle()
            .fill(Color.bsMain)
            .frame(width: thumbSize, height: thumbSize)

          Text("\(Int(value))pt")
            .font(.bsMediumText)
            .lineHeight(1.0, fontSize: 13)
            .foregroundStyle(Color.bsTextBackgroundBlack)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color.bsGrayScale4)
            )
            .offset(y: -20)   // 핸들 위쪽에 위치
        }
        .position(x: progress(width: width), y: thumbSize / 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            let location = min(max(0, drag.location.x), width)
            let percent = location / width
            let approx = percent * CGFloat(steps.count - 1)
            let index = Int(round(approx))
            value = steps[index]
          }
      )
      .onTapGesture { location in
        let tapX = min(max(0, location.x), width)
        let percent = tapX / width
        let approx = percent * CGFloat(steps.count - 1)
        let index = Int(round(approx))
        value = steps[index]
      }
    }
    .frame(height: thumbSize)
    .padding(.leading, 6)
    .padding(.trailing, 16)
  }
  
  private func progress(width: CGFloat) -> CGFloat {
    guard let idx = steps.firstIndex(of: value) else { return 0 }
    let percent = CGFloat(idx) / CGFloat(steps.count - 1)
    return percent * width
  }
  
  private func markerOffset(index: Int, width: CGFloat) -> CGFloat {
    let percent = CGFloat(index) / CGFloat(steps.count - 1)
    return percent * width
  }
}
