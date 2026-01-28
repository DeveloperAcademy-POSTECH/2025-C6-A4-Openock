//
//  OnboardingView.swift
//  Openock
//
//  Created by JiJooMaeng on 2026/01/20.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Welcome to Openock!")
                .font(.largeTitle)
                .padding()

            Text("This is the onboarding screen.")
                .padding()

            Button("Get Started") {
                dismiss()
            }
            .padding()
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
