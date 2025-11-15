//
//  CustomSwitchToggleStyle.swift
//  Openock
//
//  Created by enoch on 11/15/25.
//

import SwiftUI

struct CustomSwitchToggleStyle: ToggleStyle {
  var onColor: Color = .bsMain
  var offColor: Color = .bsGrayScale3
  var width: CGFloat = 40
  var height: CGFloat = 20
  var knobSize: CGFloat = 18
  
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label
      
      ZStack(alignment: configuration.isOn ? .trailing : .leading) {
        RoundedRectangle(cornerRadius: height / 2)
          .fill(configuration.isOn ? onColor : offColor)
          .frame(width: width, height: height)
        
        Circle()
          .fill(Color.white)
          .frame(width: knobSize, height: knobSize)
          .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
          .padding(1)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
          configuration.isOn.toggle()
        }
      }
    }
  }
}
