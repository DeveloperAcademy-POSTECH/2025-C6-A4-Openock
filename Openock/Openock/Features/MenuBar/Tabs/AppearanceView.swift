//
//  AppearanceView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct AppearanceView: View {
  @EnvironmentObject var settings: SettingsManager
  
  enum FontChoice: String, CaseIterable {
    case sfPro = "SF Pro"
    case noto = "Noto Serif KR"
    
    var displayText: String {
      switch self {
      case .sfPro: return "이것은 SF Pro 입니다."
      case .noto: return "이것은 Noto Serif KR 입니다."
      }
    }
  }

  private let sizeRange: ClosedRange<CGFloat> = 18...64

  enum CaptionBG: String, CaseIterable {
    case black = "블랙"
    case white = "화이트"
    case clear = "투명"
    case custom = "커스텀"
    
    var bgKey: String {
      switch self {
      case .black: return "black"
      case .white: return "white"
      case .clear: return "clear"
      case .custom: return "custom"
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 서체
      VStack(alignment: .leading, spacing: 6) {
        Text("서체")
          .font(.system(size: 11))
          .fontWeight(.semibold)

        Form {
          Section {
            ForEach(FontChoice.allCases, id: \.self) { option in
              Button {
                settings.selectedFont = option.rawValue
                settings.save()
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(settings.selectedFont == option.rawValue ? Color.accentColor : Color.clear)
                    .frame(width: 16)

                  Text(option.displayText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)

                  Spacer()
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
        .formStyle(.grouped)
        .padding(.horizontal, -24)
        .padding(.vertical, -24)
      }

      // 크기
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
      .padding(.bottom, 44)

      // 자막배경
      VStack(alignment: .leading, spacing: 6) {
        Divider()
          .padding(.horizontal, -24)
        
        Text("자막배경")
          .font(.system(size: 11))
          .fontWeight(.semibold)

        Form {
          Section {
            HStack(spacing: 8) {
              ForEach(CaptionBG.allCases, id: \.self) { option in
                Button {
                  settings.selectedBackground = option.rawValue
                  print(settings.selectedBackground)
                  settings.save()
                } label: {
                  VStack(spacing: 4) {
                    ZStack {
                      switch option {
                      case .black:
                        Color.black
                        Text("가").foregroundStyle(.white)
                      case .white:
                        Color.white
                        Text("가").foregroundStyle(.black)
                      case .clear:
                        Color.clear.glassEffect(.clear, in: .containerRelative)
                        Text("가").foregroundStyle(.gray)
                      case .custom:
                        Color.pink.opacity(0.3)
                        Text("가").foregroundStyle(.red)
                      }
                    }
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.selectedBackground == option.rawValue ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: settings.selectedBackground == option.rawValue ? 2 : 1)
                    )

                    Text(option.rawValue)
                      .font(.system(size: 10))
                      .foregroundStyle(.secondary)
                  }
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
          }
        }
        .formStyle(.grouped)
        .padding(.horizontal, -24)
        .padding(.vertical, -24)
      }
      .padding(.top, -24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  AppearanceView()
    .environmentObject(SettingsManager())
}
