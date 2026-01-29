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
        if currentPage < 3 {
            // 페이지 0, 1, 2 레이아웃
            HStack(alignment: .bottom) {
                // 텍스트 + 버튼 영역
                VStack(alignment: .leading, spacing: 8) {
                    if currentPage == 0 {
                        Text("BOSO 시작하기")
                            .font(.onboardingTitle1)
                            .foregroundStyle(Color.bsTextBackgroundWhite)

                        Text("화면을 통해 내 Mac에서 나오는 모든 소리가 자막으로 표시됩니다.\n화면에서 마우스가 벗어나면, 모든 버튼은 잠시 후 숨겨집니다.")
                            .font(.onboardingBody1)
                            .lineHeight(1.5, fontSize: 16)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("􀇾 전체 화면 사용 시 자막이 처음에 제한됩니다.")
                            .font(.onboardingCaption)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                    } else if currentPage == 1 {
                        Text("대화를 멈추거나 새로 시작하기")
                            .font(.onboardingTitle1)
                            .foregroundStyle(Color.bsTextBackgroundWhite)

                        Text("하단 버튼, 또는 스페이스 바를 눌러 자막을 잠시 멈출 수 있습니다.\n다시 시작하면 새로운 대화가 기록됩니다.")
                            .font(.onboardingBody1)
                            .lineHeight(1.5, fontSize: 16)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("􀇾 새로 시작 시 이전 기록은 자동으로 초기화됩니다.")
                            .font(.onboardingCaption)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                    } else {
                        Text("소리를 눈으로 확인하세요")
                            .font(.onboardingTitle1)
                            .foregroundStyle(Color.bsTextBackgroundWhite)

                        Text("목소리가 커지면 자막도 커지고 색상이 강조됩니다.\n함성 소리나 호루라기 소리에는 특별한 반응을 보입니다.")
                            .font(.onboardingBody1)
                            .lineHeight(1.5, fontSize: 16)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("􀇾 설정 > 기능 설정에서 언제든 끄고 켤 수 있습니다.")
                            .font(.onboardingCaption)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
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
                                .font(.onboardingButton)
                                .foregroundStyle(Color.bsTextBackgroundWhite)
                                .frame(width: 80, height: 29)
                                .background(
                                    Group {
                                        if currentPage >= 1 {
                                            Capsule()
                                                .fill(Color.bsGrayGlass)
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
                                // 페이지 2에서 Next 누르면 페이지 3으로 이동 + 위치 변경
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPage = 3
                                }
                                OnboardingWindowManager.shared.moveToMenuBar()
                            }
                        } label: {
                            Text("Next")
                                .font(.onboardingButton)
                                .foregroundStyle(Color.bsTextBackgroundWhite)
                                .frame(width: 80, height: 29)
                                .background(
                                    Capsule()
                                        .fill(Color.bsMain)
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.top, 12)
                }
                .frame(width: 450)

                // 이미지 영역
                Image(currentPage == 2 ? "onboarding3" : "onboarding2")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 194, height: 132)
                    .offset(x: -10)
                    .opacity(currentPage >= 1 ? 1 : 0)
            }
        } else {
            // 페이지 3 레이아웃 (메뉴바 하단, 321x356)
            VStack(spacing: 0) {
                // 상단 이미지
                Image("onboarding4")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 321, height: 191)
                    .clipped()

                // 하단 텍스트 + 버튼
                VStack(alignment: .leading, spacing: 0) {
                    Text("원하는 대로 설정하세요")
                        .font(.onboardingTitle2)
                        .lineHeight(1.5, fontSize: 24)
                        .foregroundStyle(Color.bsTextBackgroundBlack)

                    Text("상단 메뉴바의 BOSO 아이콘을 눌러\n서체, 크기, 자막 스타일을 변경할 수 있습니다.")
                        .font(.onboardingBody2)
                        .lineHeight(1.5, fontSize: 12)
                        .foregroundStyle(Color.bsTextBackgroundBlack)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        OnboardingWindowManager.shared.hide()
                    } label: {
                        Text("Start")
                            .font(.onboardingButton)
                            .foregroundStyle(Color.bsTextBackgroundWhite)
                            .frame(width: 80, height: 29)
                            .background(
                                Capsule()
                                    .fill(Color.bsMain)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Color.bsTextBackgroundWhite)
            }
            .frame(width: 321, height: 356)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}
