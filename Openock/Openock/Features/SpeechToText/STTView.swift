//
//  STTView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import SwiftUI

struct STTView: View {
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
  STTView()
}
