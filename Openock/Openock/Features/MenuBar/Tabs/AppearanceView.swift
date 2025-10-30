//
//  AppearanceView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct AppearanceView: View {
  enum FontChoice: String, CaseIterable {
    case sfPro = "이것은 SF Pro 입니다."
    case noto = "이것은 Noto Serif KR 입니다."
  }
  @State private var fontChoice: FontChoice = .sfPro

  @State private var fontSize: Double = 24
  private let sizeRange: ClosedRange<Double> = 18...64

  enum CaptionBG: String, CaseIterable {
    case black = "블랙"
    case white = "화이트"
    case clear = "투명"
    case custom = "커스텀"
  }
  @State private var captionBG: CaptionBG = .black

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
                fontChoice = option
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fontChoice == option ? Color.accentColor : Color.clear)
                    .frame(width: 16)

                  Text(option.rawValue)
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
            Text("\(Int(fontSize))pt")
              .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text("크게")
              .font(.system(size: 20))
              .foregroundStyle(.secondary)
          }
          Slider(value: $fontSize, in: sizeRange, step: 16)
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
                  captionBG = option
                } label: {
                  VStack(spacing: 4) {
                    ZStack {
                      if option == .black {
                        Color.black
                        Text("가").foregroundStyle(.white)
                      } else if option == .white {
                        Color.white
                        Text("가").foregroundStyle(.black)
                      } else if option == .clear {
                        Color.clear
                        Text("가").foregroundStyle(.gray)
                      } else {
                        Color.pink.opacity(0.3)
                        Text("가").foregroundStyle(.primary)
                      }
                    }
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(captionBG == option ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: captionBG == option ? 2 : 1)
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
}
