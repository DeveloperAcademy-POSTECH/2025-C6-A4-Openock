//
//  OverlayManager.swift
//  Openock
//
//  Created by ellllly on 11/5/25.
//

import Foundation
import Combine

final class OverlayManager: ObservableObject {
  @Published var currentText: String = "해당 없음"
  @Published var isVisible: Bool = false
  
  private var hideTask: Task<Void, Never>?
  //private var lastShowText: String = ""
  
  func show(_ text: String, duration: TimeInterval = 8.0) {
    guard text != "해당 없음" else {
      hide()
      return
    }
    
    
    
    currentText = text
    //lastShowText = text
    isVisible = true
    
    hideTask?.cancel()
    
    hideTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
      
      if !Task.isCancelled {
        await MainActor.run { [weak self] in
          self?.isVisible = false
          self?.currentText = "해당 없음"
        }
      }
    }
    print("✅ [OverlayManager] Showing: \(text) (will hide in \(duration)s)")
  }
  
  func hide() {
    hideTask?.cancel()
    isVisible = false
    currentText = "해당 없음"
  }
}
