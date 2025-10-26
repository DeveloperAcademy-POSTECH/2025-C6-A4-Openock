//
//  LiveCaptionView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

struct LiveCaptionView: View {
  var body: some View {
    ZStack {
      Color.clear
        .glassEffect(.clear, in: .rect)
        .ignoresSafeArea()
      
      VStack {
        Image(systemName: "globe")
          .imageScale(.large)
          .foregroundStyle(.tint)
        Text("Hello, world!")
          .font(.title)
          .foregroundStyle(.primary)
      }
      .padding()
    }
  }
}

#Preview {
  LiveCaptionView()
}
