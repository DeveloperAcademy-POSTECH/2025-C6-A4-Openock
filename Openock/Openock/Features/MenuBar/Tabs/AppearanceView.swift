//
//  AppearanceView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct AppearanceView: View {
  @EnvironmentObject var settings: SettingsManager
  
  private let sizeRange: ClosedRange<CGFloat> = 18...64
  
  @State private var fontPickerPanel: NSPanel?
  
  @State private var fontGlobalMonitor: Any?
  @State private var fontLocalMonitor: Any?
  @State private var colorGlobalMonitor: Any?
  @State private var colorLocalMonitor: Any?
  
  enum CaptionBG: String, CaseIterable {
    case black = "블랙"
    case white = "화이트"
    case gray = "그레이"
    case contrast = "고대비"
  }
  
  enum HighlightColor: String, CaseIterable {
    case none
    case red
    case orange
    case yellow
    case green
    case mint
    case sky
    case blue
    case purple
    
    var color: Color {
      switch self {
      case .none: return .gray.opacity(0.3)
      case .red: return .red
      case .orange: return .orange
      case .yellow: return .yellow
      case .green: return .green
      case .mint: return .mint
      case .sky: return .cyan
      case .blue: return .blue
      case .purple: return .purple
      }
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      fontSelectView
      sizeSelectView
      backgroundSelectView
      highlightSelectView
    }
  }
  
  // MARK: - 서체 선택 View
  var fontSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("서체")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      Button(action: {
        openFontPickerPanel()
      }, label: {
        HStack(alignment: .center) {
          Text(settings.selectedFont.isEmpty ? "서체 선택" : settings.selectedFont)
            .lineLimit(1)
          
          Spacer()
          
          Image(systemName: "chevron.down")
            .font(.system(size: 10))
            .padding(10)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .inset(by: 0.34)
            .stroke(Color(red: 0.94, green: 0.94, blue: 0.94), lineWidth: 0.67121)
        )
      })
      .buttonStyle(.plain)
    }
  }
  
  // MARK: - 크기 선택 View
  var sizeSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("크기")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      ZStack {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .bottom) {
            Text("작게")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
            Spacer()
            Text("크게")
              .font(.system(size: 20))
              .foregroundStyle(.secondary)
          }
          
          Slider(value: $settings.fontSize, in: sizeRange, step: 16)
            .onChange(of: settings.fontSize) {
              settings.save()
            }
          
        }
        .padding(16)
        .background(Color(NSColor.quaternaryLabelColor).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Text("\(Int(settings.fontSize))pt")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.primary)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color.gray)
              )
              .offset(x: thumbXPosition(in: geo.size.width - 35) + 10, y: 25)
              .animation(.easeInOut(duration: 0.15), value: settings.fontSize)
          }
        }
      }
    }
  }
  
  // MARK: - 자막 배경 선택 View
  var backgroundSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("자막 스타일")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      HStack {
        ForEach(CaptionBG.allCases, id: \.self) { option in
          Button {
            settings.selectedBackground = option.rawValue
            settings.save()
          } label: {
            VStack(spacing: 6) {
              ZStack {
                switch option {
                case .black:
                  Color.black
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                  Text("가").foregroundStyle(.white)
                case .white:
                  Color.white
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                  Text("가")
                    .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.24))
                case .gray:
                  Color.gray
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                  Text("가")
                    .foregroundColor(Color.white)
                case .contrast:
                  Color.yellow
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                  Text("가")
                    .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.24))
                }
              }
              .font(.system(size: 20, weight: .semibold))
              .frame(width: 67, height: 67)
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(settings.selectedBackground == option.rawValue ? Color.purple : Color.clear, lineWidth: 2)
              )
              Text(option.rawValue)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          
          if option != .contrast {
            Spacer()
          }
        }
      }
      .padding(6)
      .background(Color(NSColor.quaternaryLabelColor).opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
    }
  }
  
  // MARK: - 자막 강조 색상 선택 View
  var highlightSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("자막 스타일")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      HStack {
        ForEach(HighlightColor.allCases, id: \.self) { option in
          Button {
            settings.selectedHighlight = option.rawValue
            settings.save()
          } label: {
            if option == .none {
              Image(systemName: "xmark.circle")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundStyle(Color.white)
            } else {
              Circle()
                .fill(option.color)
                .overlay(
                  Circle()
                    .stroke(settings.selectedHighlight == option.rawValue ? Color.purple : Color.clear, lineWidth: 2)
                  )
            }
          }
          .frame(width: 25, height: 25)
          .buttonStyle(.plain)
          
          if option != .purple {
            Spacer()
          }
        }
      }
      .padding(8)
      .background(Color(NSColor.quaternaryLabelColor).opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
    }
  }
  
  
  // MARK: - Font Panel
  private func openFontPickerPanel() {
    if fontPickerPanel != nil { fontPickerPanel?.makeKeyAndOrderFront(nil); return }
    
    let contentView = FontPickerSheetView(isPresented: Binding(
      get: { fontPickerPanel != nil },
      set: { if !$0 { closeFontPickerPanel() } }
    )).environmentObject(settings)
    
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 249, height: 321),
      styleMask: [.nonactivatingPanel, .utilityWindow, .closable],
      backing: .buffered, defer: false
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.level = .floating
    panel.contentView = NSHostingView(rootView: AnyView(contentView))
    panel.makeKeyAndOrderFront(nil)
    fontPickerPanel = panel
    
    // 메뉴바 팝오버(즉 MenuBarView) 윈도우 찾기 — 너비 기준으로 시도
    if let menuBarWindow = NSApp.windows.first(where: {
      // NSHostingView의 제네릭 문제 피하려면 contentView 타입 확인 대신 너비/위치로 유추
      abs($0.frame.width - 346) < 2 && $0.isVisible
    }) {
      let rect = menuBarWindow.frame
      
      // 오른쪽에 붙이기 (원하면 왼쪽으로 바꿀 수 있음)
      let origin = CGPoint(x: rect.minX - 257, y: rect.minY - 30) // 위쪽 정렬
      panel.setFrameOrigin(origin)
      
      
      fontGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak panel] _ in
        guard let panel = panel else { return }
        let loc = NSEvent.mouseLocation
        if !panel.frame.contains(loc) { closeFontPickerPanel() }
      }
      fontLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak panel] event in
        guard let panel = panel else { return event }
        let loc = event.window?.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin ?? NSEvent.mouseLocation
        if !panel.frame.contains(loc) { closeFontPickerPanel() }
        return event
      }
    }
  }
  
  private func closeFontPickerPanel() {
    if let panel = fontPickerPanel { panel.close() }
    if let g = fontGlobalMonitor { NSEvent.removeMonitor(g); fontGlobalMonitor = nil }
    if let l = fontLocalMonitor { NSEvent.removeMonitor(l); fontLocalMonitor = nil }
    fontPickerPanel = nil
  }
  
  // MARK: - slider handle position
  private func thumbXPosition(in width: CGFloat) -> CGFloat {
    let progress = (settings.fontSize - sizeRange.lowerBound) / (sizeRange.upperBound - sizeRange.lowerBound)
    let thumbWidth: CGFloat = 20
    return CGFloat(progress) * (width - thumbWidth)
  }
}
