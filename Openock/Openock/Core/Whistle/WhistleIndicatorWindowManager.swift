import SwiftUI
import AppKit
import Combine

/// 휘슬 인디케이터 창을 관리하는 매니저
class WhistleIndicatorWindowManager: ObservableObject {
    private var indicatorWindow: WhistleIndicatorWindow?
    private var cancellables = Set<AnyCancellable>()
    private weak var mainWindow: NSWindow?
    private var pipeline: AudioPipeline

    init(pipeline: AudioPipeline) {
        self.pipeline = pipeline
        // 메인 스레드에서 창 설정
        DispatchQueue.main.async { [weak self] in
            self?.setupIndicatorWindow()
            self?.observeWhistleDetection()
            self?.observeMainWindowFrameChanges()
        }
    }

    private func setupIndicatorWindow() {
        indicatorWindow = WhistleIndicatorWindow()
        indicatorWindow?.hasShadow = false
        indicatorWindow?.isOpaque = false
        indicatorWindow?.backgroundColor = .clear

        // SwiftUI 뷰를 NSHostingView로 래핑하여 창에 추가
        let contentView = NSHostingView(rootView: WhistleIndicatorContent()
            .environmentObject(pipeline)
        )
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false
        indicatorWindow?.contentView = contentView

        // 테스트를 위해 초기 위치 설정 및 표시
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            guard let self = self, let window = self.indicatorWindow else { return }
//            if let mainWindow = self.getMainWindow() {
//                window.updatePosition(for: mainWindow)
//                if window.parent != mainWindow {
//                    mainWindow.addChildWindow(window, ordered: .above)
//                }
//                window.makeKeyAndOrderFront(nil)
//            }
//        }
    }

    /// 휘슬 감지 상태 관찰
    private func observeWhistleDetection() {
        pipeline.$isWhistleDetected
            .sink { [weak self] isDetected in
                guard let self = self, let window = self.indicatorWindow else { return }

                if isDetected {
                    // 메인 창 위치 업데이트 후 표시
                    if let mainWindow = self.getMainWindow() {
                        window.updatePosition(for: mainWindow)
                        // 메인 창의 child로 추가하여 자동으로 따라오게 설정 (중복 방지)
                        if window.parent != mainWindow {
                            mainWindow.addChildWindow(window, ordered: .above)
                        }
                    }
                    window.show()
                }
            }
            .store(in: &cancellables)
    }

    /// 메인 창의 프레임 변경 관찰
    private func observeMainWindowFrameChanges() {
        // NSWindow.didResizeNotification과 NSWindow.didMoveNotification 관찰
        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)
            .sink { [weak self] notification in
                guard let self = self,
                      let window = notification.object as? NSWindow,
                      let mainWindow = self.getMainWindow(),
                      window == mainWindow,
                      let indicatorWindow = self.indicatorWindow else { return }

                // 메인 창의 크기가 변경될 때 호루라기 창 위치 업데이트
                indicatorWindow.updatePosition(for: mainWindow, animated: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)
            .sink { [weak self] notification in
                guard let self = self,
                      let window = notification.object as? NSWindow,
                      let mainWindow = self.getMainWindow(),
                      window == mainWindow,
                      let indicatorWindow = self.indicatorWindow else { return }

                // 메인 창이 이동할 때 호루라기 창 위치 업데이트
                indicatorWindow.updatePosition(for: mainWindow, animated: false)
            }
            .store(in: &cancellables)
    }

    /// 메인 창 가져오기
    private func getMainWindow() -> NSWindow? {
        if mainWindow == nil || mainWindow?.isVisible == false {
            // NSPanel이 아닌 일반 NSWindow 중에서 가장 먼저 보이는 것
            mainWindow = NSApp.windows.first { window in
                !(window is NSPanel) && window.isVisible && window.title.isEmpty == false
            }

            // 위에서 못 찾으면 title 체크 없이 재시도
            if mainWindow == nil {
                mainWindow = NSApp.windows.first { window in
                    !(window is NSPanel) && window.isVisible
                }
            }
        }
        return mainWindow
    }
}

/// 휘슬 인디케이터 표시용 SwiftUI 뷰
private struct WhistleIndicatorContent: View {
    @EnvironmentObject var pipeline: AudioPipeline

  var body: some View {
    ZStack {
      if pipeline.isWhistleDetected {
        HStack(spacing: 8) {
          // Whistle icon from asset
          Image("whistle")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.bsTextBackgroundWhite)
            .frame(width: 30, height: 30)
          
          // Label
          Text("휘슬")
            .font(.bsTag)
            .lineHeight(1.5, fontSize: 24)
            .foregroundColor(Color.bsTextBackgroundWhite)
        }
        .padding(.horizontal, 12)
        .frame(width: 106, height: 48, alignment: .center)
        .contentShape(Capsule())
        .background(
          Capsule()
            .fill(Color.bsTextBackgroundBlack)
        )
        .overlay(
          Capsule()
            .stroke(Color.bsSub1, lineWidth: 2)
        )
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: pipeline.isWhistleDetected)
      }
    }
    // A minimum size similar to the reference badge (kept flexible)
    .frame(width: 106, height: 48)
  }
}
