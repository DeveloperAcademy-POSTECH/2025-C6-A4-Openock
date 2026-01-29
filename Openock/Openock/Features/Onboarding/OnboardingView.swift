//
//  OnboardingView.swift
//  Openock
//
//  Created by JiJooMaeng on 2026/01/20.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 텍스트 + 버튼 영역
            VStack(alignment: .leading, spacing: 8) {
                if currentPage == 0 {
                    Text("BOSO 시작하기")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("화면을 통해 내 Mac에서 나오는 모든 소리가 자막으로 표시됩니다.\n화면에서 마우스가 벗어나면, 모든 버튼은 잠시 후 숨겨집니다.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("􀇾 전체 화면 사용 시 자막이 처음에 제한됩니다.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                } else if currentPage == 1 {
                    Text("대화를 멈추거나 새로 시작하기")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("하단 버튼, 또는 스페이스 바를 눌러 자막을 잠시 멈출 수 있습니다.\n다시 시작하면 새로운 대화가 기록됩니다.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("􀇾 새로 시작 시 이전 기록은 자동으로 초기화됩니다.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("소리를 눈으로 확인하세요")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("목소리가 커지면 자막도 커지고 색상이 강조됩니다.\n함성 소리나 호루라기 소리에는 특별한 반응을 보입니다.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("􀇾 설정 > 기능 설정에서 언제든 끄고 켤 수 있습니다.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }

                HStack(spacing: 8) {
                    Button {
                        if currentPage == 0 {
                            OnboardingWindowManager.shared.hide()
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage -= 1
                            }
                        }
                    } label: {
                        Text(currentPage == 0 ? "Skip" : "Back")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 80, height: 29)
                            .background(
                                Group {
                                    if currentPage >= 1 {
                                        Capsule()
                                            .stroke(.white.opacity(0.5), lineWidth: 1)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        if currentPage < 2 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        } else {
                            OnboardingWindowManager.shared.hide()
                        }
                    } label: {
                        Text(currentPage == 2 ? "Done" : "Next")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 29)
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
                .padding(.top, 12)
            }
            .frame(width: 450)

            // 이미지 영역 (항상 공간 확보, 페이지 0에서는 투명)
            Image(currentPage == 2 ? "onboarding3" : "onboarding2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 194, height: 132)
                .opacity(currentPage >= 1 ? 1 : 0)
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
