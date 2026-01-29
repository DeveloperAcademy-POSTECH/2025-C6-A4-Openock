//
//  OnboardingView.swift
//  Openock
//
//  Created by JiJooMaeng on 2026/01/20.
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("BOSO 시작하기")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text("화면을 통해 내 Mac에서 나오는 모든 소리가 자막으로 표시됩니다.\n화면에서 마우스가 벗어나면, 모든 버튼은 잠시 후 숨겨집니다.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: .constant(true)) {
                    Text("􀇾 전체 화면 사용 시 자막이 처음에 제한됩니다.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 6)

                HStack(spacing: 10) {
                    Button {
                        OnboardingWindowManager.shared.hide()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Next -> hide window
                        OnboardingWindowManager.shared.hide()
                    } label: {
                        Text("Next")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 18)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.36, green: 0.45, blue: 1.0),
                                                Color(red: 0.22, green: 0.33, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(18)
            .frame(width: 450)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
            .padding(.horizontal, 18)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? .white : .white.opacity(0.7))

                configuration.label

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
