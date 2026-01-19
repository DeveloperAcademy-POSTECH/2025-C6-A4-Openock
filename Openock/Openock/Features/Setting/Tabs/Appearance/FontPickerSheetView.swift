//
//  FontPickerSheetView.swift
//  Openock
//
//  Created by enoch on 11/8/25.
//

import SwiftUI

struct FontPickerSheetView: View {
  @EnvironmentObject var settings: SettingsManager
  @Binding var isPresented: Bool
  
  @State private var searchText = ""
  @State private var tempSelectedFont: String = ""
  
  private let fonts = NSFontManager.shared.availableFonts.sorted()
  
  private var filteredFonts: [String] {
    if searchText.isEmpty {
      return fonts
    } else {
      return fonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // 헤더, 검색창, 구분선
      topContentView
      // 폰트 리스트
      fontScrollView
    }
    .onAppear {
      tempSelectedFont = settings.selectedFont
    }
  }
  
  // MARK: - 헤더, 검색창, 구분선
  var topContentView: some View {
    VStack(spacing: 4) {
      // 헤더
      HStack(alignment: .center) {
        Text("서체")
          .font(.bsTitle)
          .lineHeight(1.5, fontSize: 11)
          .foregroundStyle(Color.bsGrayScale1)
        Spacer()
        Button(action: {
          isPresented = false
        }, label: {
          Image(systemName: "xmark")
            .font(.system(size: 10))
            .foregroundStyle(Color.bsTextBackgroundBlack)
        })
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 8)
      .padding(.top, 16)
      
      // 검색창
      HStack(alignment: .center) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 10))
          .foregroundStyle(Color.bsTextBackgroundBlack)
          .padding(6)
        
        TextField("", text: $searchText)
          .textFieldStyle(.plain)
          .font(.bsFontCaption2)
          .foregroundStyle(Color.bsTextBackgroundBlack)
          .lineHeight(1.5, fontSize: 16)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 15)
          .foregroundStyle(Color.bsGrayScale5)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 15)
          .inset(by: 0.34)
          .stroke(Color.bsGrayScale4, lineWidth: 0.67)
      )
      .padding(.horizontal, 8)
      .padding(.bottom, 4)
      
      Divider()
    }
  }
  
  // MARK: - 폰트 리스트
  var fontScrollView: some View {
    // 폰트 리스트
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(filteredFonts.enumerated()), id: \.offset) { _, fontName in
          Button {
            settings.selectedFont = fontName
            settings.save()
            isPresented = false
          } label: {
            HStack {
              Text(fontName)
                .font(.bsFontCaption2)
                .lineHeight(1.5, fontSize: 16)
                .foregroundStyle(Color.bsTextBackgroundBlack)
              Spacer()
              if settings.selectedFont == fontName {
                Image(systemName: "checkmark")
                  .font(.system(size: 11))
                  .foregroundStyle(Color.bsSub1)
              }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 4)
    }
  }
}

#Preview("서체 선택 시트") {
  FontPickerSheetView(isPresented: .constant(true))
    .environmentObject(SettingsManager())
}
