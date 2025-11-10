//
//  ColorPickerSheetView.swift
//  Openock
//
//  Created by enoch on 11/9/25.
//

import SwiftUI
import AppKit

final class ColorPickerCoordinator: NSObject {
  var settings: SettingsManager
  var colorType: ColorPickerSheetView.ColorType?
  
  init(settings: SettingsManager) {
    self.settings = settings
    super.init()
  }
  
  @objc func colorChanged(_ sender: NSColorPanel) {
    guard let type = colorType else { return }
    let ns = sender.color
    let swiftUIColor = Color(nsColor: ns)
    switch type {
    case .background:
      settings.customBackgroundColor = swiftUIColor
    case .text:
      settings.customTextColor = swiftUIColor
    }
    settings.selectedBackground = "커스텀"
    settings.save()
  }
}

struct ColorPickerSheetView: View {
  @EnvironmentObject var settings: SettingsManager
  @Binding var isPresented: Bool
  var onClose: (() -> Void)? = nil
  
  @State private var coordinator: ColorPickerCoordinator?
  @State private var showColorPanelType: ColorType? = nil
  
  enum ColorType {
    case background, text
  }
  
  var body: some View {
    VStack(spacing: 0) {
      topContentView
      pickerContentView
    }
    .onAppear {
      // coordinator 초기화 (NSColorPanel 이벤트 전달용)
      if coordinator == nil {
        coordinator = ColorPickerCoordinator(settings: settings)
      }
    }
  }
  
  // MARK: - 헤더, 구분선
  var topContentView: some View {
    VStack(spacing: 4) {
      // 헤더
      HStack(alignment: .center) {
        Text("커스텀 자막배경")
          .font(.system(size: 11, weight: .semibold))
        Spacer()
        Button(action: {
          settings.selectedBackground = "커스텀"
          settings.save()
          onClose?()
          isPresented = false
        }, label: {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .semibold))
        })
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 8)
      .padding(.top, 16)
      
      Divider()}
  }
  
  var pickerContentView: some View {
    VStack(alignment: .leading, spacing: 12) {
      colorButton(title: "배경 색상", color: settings.customBackgroundColor, type: .background)
      colorButton(title: "글자 색상", color: settings.customTextColor, type: .text)
    }
    .padding(.horizontal, 8)
    .padding(.bottom, 10)
  }
  
  // MARK: - 색상 버튼
  private func colorButton(title: String, color: Color, type: ColorType) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      Button {
        showColorPanelType = type
        openNSColorPanel(for: type)
      } label: {
        RoundedRectangle(cornerRadius: 6)
          .fill(color)
          .frame(height: 33)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(NSColor.separatorColor), lineWidth: 1)
          )
          .overlay(
            Text("선택")
              .font(.system(size: 10))
              .foregroundColor(.secondary)
          )
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - NSColorPanel 제어
  private func openNSColorPanel(for type: ColorType) {
    guard let coordinator else { return }
    coordinator.colorType = type

    let panel = NSColorPanel.shared
    panel.setTarget(coordinator)
    panel.setAction(#selector(ColorPickerCoordinator.colorChanged(_:)))

    switch type {
    case .background:
      panel.color = NSColor(settings.customBackgroundColor)
    case .text:
      panel.color = NSColor(settings.customTextColor)
    }

    panel.makeKeyAndOrderFront(nil)
    panel.backgroundColor = .white

    // ✅ color picker 열릴 때 isColorPickerActive를 true로
    DispatchQueue.main.async {
      NSApp.windows.forEach { window in
        if window.title.contains("Color Picker") {
          window.backgroundColor = .white // ✅ 배경색 흰색으로
        }
      }
    }
  }
}
