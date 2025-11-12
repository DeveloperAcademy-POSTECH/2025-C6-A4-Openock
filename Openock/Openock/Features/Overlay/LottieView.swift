//
//  LottieView.swift
//  Openock
//
//  Created by ellllly on 11/12/25.
//

import SwiftUI
import Lottie

struct LottieView: NSViewRepresentable {
  var name: String
  var loopMode: LottieLoopMode = .playOnce
  var onAnimationFinished: (() -> Void)? = nil

  func makeNSView(context: Context) -> LottieAnimationView {
    let animationView = LottieAnimationView(animation: LottieAnimation.named(name))
    animationView.contentMode = .scaleAspectFit
    animationView.loopMode = loopMode
    return animationView
  }

  func updateNSView(_ nsView: LottieAnimationView, context: Context) {
    if !nsView.isAnimationPlaying {
      nsView.play { finished in
        if finished {
          self.onAnimationFinished?()
        }
      }
    }
    if nsView.loopMode != loopMode {
      nsView.loopMode = loopMode
    }
  }
}
