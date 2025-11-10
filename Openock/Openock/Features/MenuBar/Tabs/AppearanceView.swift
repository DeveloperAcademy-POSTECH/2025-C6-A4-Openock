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
  @State private var colorPickerPanel: NSPanel?
  
  @State private var fontGlobalMonitor: Any?
  @State private var fontLocalMonitor: Any?
  @State private var colorGlobalMonitor: Any?
  @State private var colorLocalMonitor: Any?
  
  enum CaptionBG: String, CaseIterable {
    case black = "블랙"
    case white = "화이트"
    case custom = "커스텀"
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // 서체
      fontSelectView
      // 크기
      sizeSelectView
      // 자막배경
      backgroundSelectView
    }
  }
  
  // MARK: - 서체 선택
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
  
  // MARK: - 크기 선택
  var sizeSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("크기")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          Text("작게")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(Int(settings.fontSize))pt")
            .font(.system(size: 12, weight: .semibold))
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
    }
  }
  
  // MARK: - 자막 배경 선택
  var backgroundSelectView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("자막배경")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      HStack {
        ForEach(CaptionBG.allCases, id: \.self) { option in
          Button {
            if option == .custom {
              openColorPickerPanel()
            }
            settings.selectedBackground = option.rawValue
            settings.save()
          } label: {
            VStack(spacing: 6) {
              ZStack {
                switch option {
                case .black:
                  Color.black
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                  Text("가").foregroundStyle(.white)
                case .white:
                  Color.white
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                  Text("가")
                    .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.24))
                case .custom:
                  VStack(spacing: -8) {
                    HStack(spacing: -8) {
                      Circle()
                        .frame(width: 37.1694, height: 37.1694)
                        .foregroundStyle(Color(red: 1, green: 0.26, blue: 0.73).opacity(0.7))
                        .blur(radius: 2.73855)
                      
                      Circle()
                        .frame(width: 37.1694, height: 37.1694)
                        .foregroundStyle(Color(red: 1, green: 0.99, blue: 0.32).opacity(0.7))
                        .blur(radius: 2.73855)
                    }
                    
                    HStack(spacing: -8) {
                      Circle()
                        .frame(width: 37.1694, height: 37.1694)
                        .foregroundStyle(Color(red: 0.22, green: 0.94, blue: 1).opacity(0.7))
                        .blur(radius: 2.73855)
                      
                      Circle()
                        .frame(width: 37.1694, height: 37.1694)
                        .foregroundStyle(Color(red: 0.88, green: 0.88, blue: 0.88).opacity(0.7))
                        .blur(radius: 2.73855)
                    }
                  }
                  Text("가")
                    .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.24))
                }
              }
              .font(.system(size: 20, weight: .semibold))
              .frame(width: 67, height: 67)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(settings.selectedBackground == option.rawValue ? Color.accentColor : Color.clear, lineWidth: 2)
              )
              
              Text(option.rawValue)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          
          if option != .custom {
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
  
  // MARK: - Color Panel
  private func openColorPickerPanel() {
    if colorPickerPanel != nil { colorPickerPanel?.makeKeyAndOrderFront(nil); return }
    
    settings.isColorPickerOpen = true
    
    let contentView = ColorPickerSheetView(isPresented: Binding(
      get: { colorPickerPanel != nil },
      set: { if !$0 { closeColorPickerPanel() } }
    )).environmentObject(settings)
    
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 249, height: 171),
      styleMask: [.nonactivatingPanel, .utilityWindow, .closable],
      backing: .buffered, defer: false
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.level = .floating
    panel.contentView = NSHostingView(rootView: AnyView(contentView))
    panel.makeKeyAndOrderFront(nil)
    colorPickerPanel = panel
    
    // 메뉴바 팝오버(즉 MenuBarView) 윈도우 찾기 — 너비 기준으로 시도
    if let menuBarWindow = NSApp.windows.first(where: {
      // NSHostingView의 제네릭 문제 피하려면 contentView 타입 확인 대신 너비/위치로 유추
      abs($0.frame.width - 346) < 2 && $0.isVisible
    }) {
      let rect = menuBarWindow.frame
      
      // 오른쪽에 붙이기 (원하면 왼쪽으로 바꿀 수 있음)
      let origin = CGPoint(x: rect.minX - 257, y: rect.minY - 40)
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
    
    if !settings.isColorPickerOpen {
      // Color Picker 열려 있을 동안 외부 클릭 감지는 최소화, MenubarView는 닫지 않음
      colorGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak panel] _ in
        guard let panel = panel else { return }
        let mouseLoc = NSEvent.mouseLocation
        // 클릭 위치가 패널 밖이면 Color Picker만 닫음
        if !panel.frame.contains(mouseLoc) {
          closeColorPickerPanel()
        }
      }
      
      colorLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak panel] event in
        guard let panel = panel else { return event }
        let screenPoint = event.window?.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin ?? NSEvent.mouseLocation
        if !panel.frame.contains(screenPoint) {
          closeColorPickerPanel()
        }
        return event
      }
    }
  }
  
  private func closeColorPickerPanel() {
    settings.isColorPickerOpen = false
    if let panel = colorPickerPanel { panel.close() }
    if let g = colorGlobalMonitor { NSEvent.removeMonitor(g); colorGlobalMonitor = nil }
    if let l = colorLocalMonitor { NSEvent.removeMonitor(l); colorLocalMonitor = nil }
    colorPickerPanel = nil
  }
}

