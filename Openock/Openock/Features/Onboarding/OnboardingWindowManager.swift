import SwiftUI

class OnboardingWindowManager {
    static let shared = OnboardingWindowManager()
    
    private var onboardingWindow: NSWindow?
    private var hostingController: NSHostingController<OnboardingView>?

    private init() {}

    func show(relativeTo parentWindow: NSWindow) {
        // Create the window and controller only once
        if onboardingWindow == nil {
            let onboardingView = OnboardingView()
            let controller = NSHostingController(rootView: onboardingView)
            
            // Get the ideal size of the SwiftUI view
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
            
            // Configure window properties
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.contentViewController = controller
            
            // Store references
            self.hostingController = controller
            self.onboardingWindow = window

            // Link the window to its parent
            parentWindow.addChildWindow(window, ordered: .above)
        }

        // Show the window
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard let window = onboardingWindow else { return }

        // 부모 윈도우에서 child window 연결 해제
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }

        window.orderOut(nil)
        onboardingWindow = nil
        hostingController = nil
    }

    func moveToMenuBar() {
        guard let window = onboardingWindow,
              let screen = NSScreen.main else { return }

        // 부모 윈도우에서 연결 해제
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }

        let windowSize = CGSize(width: 321, height: 356)
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
