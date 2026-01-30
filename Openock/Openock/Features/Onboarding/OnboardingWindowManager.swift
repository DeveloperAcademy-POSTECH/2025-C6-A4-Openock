import SwiftUI

class OnboardingWindowManager {
    static let shared = OnboardingWindowManager()

    private var onboardingWindow: NSWindow?
    private var hostingController: NSHostingController<OnboardingView>?
    private var overlayWindow: NSWindow?
    private var parentWindowRef: NSWindow?

    private let hasSeenOnboardingKey = "hasSeenOnboarding"

    private init() {}

    private var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenOnboardingKey) }
    }

    func show(relativeTo parentWindow: NSWindow) {
        // 테스트용 - 확인 후 삭제
//        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
        
        // 이미 온보딩을 본 경우 표시하지 않음
        if hasSeenOnboarding { return }

        parentWindowRef = parentWindow

        // 오버레이 윈도우 생성
        if overlayWindow == nil {
            createOverlayWindow()
        }
        overlayWindow?.orderFront(nil)

        if onboardingWindow == nil {
            let onboardingView = OnboardingView()
            let controller = NSHostingController(rootView: onboardingView)

            let viewSize = controller.view.fittingSize

            // Calculate the desired frame
            let parentFrame = parentWindow.frame
            let newOriginX = parentFrame.minX
            let newOriginY = parentFrame.origin.y + parentFrame.height + 31
            let contentRect = CGRect(origin: CGPoint(x: newOriginX, y: newOriginY), size: viewSize)

            // Create the window with the correct frame and style
            let window = NSWindow(
                contentRect: contentRect,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.contentViewController = controller

            self.hostingController = controller
            self.onboardingWindow = window

            parentWindow.addChildWindow(window, ordered: .above)
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    private func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }

        let overlay = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        overlay.isOpaque = false
        overlay.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        overlay.level = .floating - 1
        overlay.ignoresMouseEvents = true
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.overlayWindow = overlay
    }

    func hide() {
        guard let window = onboardingWindow else { return }

        // 온보딩 완료 표시
        hasSeenOnboarding = true

        // 부모 윈도우에서 child window 연결 해제
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }

        window.orderOut(nil)
        onboardingWindow = nil
        hostingController = nil

        // 오버레이 윈도우 숨기기
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        parentWindowRef = nil
    }

    func moveToMenuBar() {
        guard let window = onboardingWindow,
              let screen = NSScreen.main else { return }

        // 부모 윈도우에서 연결 해제
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        
        // 메뉴막대 온보딩 윈도우 크기
        let windowSize = CGSize(width: 321, height: 386)
        var newOriginX: CGFloat = screen.frame.maxX - windowSize.width - 20
        let menuBarHeight = NSStatusBar.system.thickness

        // MenuBarExtra 윈도우(NSStatusBarWindow) 찾기
        for appWindow in NSApplication.shared.windows {
            let windowClassName = String(describing: type(of: appWindow))
            if windowClassName.contains("NSStatusBarWindow") {
                // StatusBar 아이콘의 중앙 위치 계산
                let statusBarFrame = appWindow.frame
                newOriginX = statusBarFrame.midX - (windowSize.width / 2)
                break
            }
        }

        // 메뉴바 바로 아래에 위치
        let newOriginY = screen.frame.maxY - menuBarHeight - windowSize.height - 8

        window.setFrame(CGRect(origin: CGPoint(x: newOriginX, y: newOriginY), size: windowSize), display: true, animate: true)
    }
}
