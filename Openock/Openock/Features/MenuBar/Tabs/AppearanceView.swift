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
  @Binding var fontChoice: FontChoice

  // 크기
  @Binding var fontSize: Double
  private let sizeRange: ClosedRange<Double> = 14...40

  // 자막배경
  enum CaptionBG: String, CaseIterable {
    case black = "블랙"
    case white = "화이트"
    case clear = "투명"
    case custom = "커스텀"
  }
  @Binding var captionBG: CaptionBG

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 18) {
        // 서체
        SectionHeader("서체")
        VStack(spacing: 0) {
          FontOptionRow(selected: $fontChoice, option: .sfPro)
          Divider().opacity(0.08)
          FontOptionRow(selected: $fontChoice, option: .noto)
        }
        .cardBackground()

        // 크기
        SectionHeader("크기")
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("작게")
              .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(fontSize))pt")
              .font(.system(size: 14, weight: .semibold))
              .padding(.vertical, 6)
              .padding(.horizontal, 10)
              .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Text("크게")
              .foregroundStyle(.secondary)
          }
          Slider(value: $fontSize, in: sizeRange, step: 1)
            .tint(.primary.opacity(0.7))
        }
        .cardBackground()

        // 자막배경
        SectionHeader("자막배경")
        CaptionBackgroundGrid(selection: $captionBG)
          .cardBackground()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Font Row
private struct FontOptionRow: View {
  @Binding var selected: AppearanceView.FontChoice
  let option: AppearanceView.FontChoice

  var body: some View {
    Button {
      selected = option
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "checkmark")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(selected == option ? Color.accentColor : Color.clear.opacity(0.001))
          .frame(width: 24)
        Text(option.rawValue)
          .font(option == .sfPro ? .system(size: 22, weight: .semibold) :
                 .system(.title3, design: .serif))
          .foregroundStyle(.primary)
        Spacer()
      }
      .contentShape(Rectangle())
      .padding(.vertical, 12)
      .padding(.horizontal, 12)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Caption BG Grid
private struct CaptionBackgroundGrid: View {
  @Binding var selection: AppearanceView.CaptionBG

  var body: some View {
    HStack(spacing: 8) {
      bgItem(style: .black)  { previewSquare(bg: .black, fg: .white, label: "가") }
      bgItem(style: .white)  { previewSquare(bg: .white, fg: .black, label: "가") }
      bgItem(style: .clear)  { previewSquare(bg: .clear, fg: .gray.opacity(0.7), label: "가").overlay(MaterialBorder()) }
      bgItem(style: .custom) {
        ZStack {
          Circle().fill(Color.pink).frame(width: 20).offset(x: -8, y: -8).opacity(0.85)
          Circle().fill(Color.cyan).frame(width: 22).offset(x: -12, y: 12).opacity(0.9)
          Circle().fill(Color.yellow).frame(width: 22).offset(x: 14, y: 2).opacity(0.9)
          Text("가").font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.primary)
        }
        .frame(width: 64, height: 64)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
    }
    .padding(6)
  }

  @ViewBuilder
  private func bgItem(style: AppearanceView.CaptionBG, @ViewBuilder content: () -> some View) -> some View {
    let isSelected = selection == style
    Button {
      selection = style
    } label: {
      VStack(spacing: 6) {
        content()
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(isSelected ? Color.accentColor.opacity(0.9) : Color.clear, lineWidth: 2.5)
          )
          .scaleEffect(isSelected ? 1.02 : 1.0)
        Text(style.rawValue)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(2)
    }
    .buttonStyle(.plain)
  }

  private func previewSquare(bg: Color, fg: Color, label: String) -> some View {
    ZStack {
      bg
      Text(label).font(.system(size: 32, weight: .semibold)).foregroundStyle(fg)
    }
    .frame(width: 64, height: 64)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(MaterialBorder())
  }
}

// MARK: - Helpers
private struct SectionHeader: View {
  let title: String
  init(_ title: String) { self.title = title }
  var body: some View {
    Text(title)
      .font(.headline)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 4)
  }
}

private struct MaterialBorder: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .strokeBorder(.white.opacity(0.15), lineWidth: 1)
      .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
  }
}

private extension View {
  func cardBackground() -> some View {
    self
      .padding(10)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(.white.opacity(0.25), lineWidth: 0.8)
      )
  }
}

#Preview {
  AppearanceView(
    fontChoice: .constant(.sfPro),
    fontSize: .constant(24),
    captionBG: .constant(.black)
  )
}
