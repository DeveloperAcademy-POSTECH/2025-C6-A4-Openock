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
        onboardingWindow?.close()
        onboardingWindow = nil
        hostingController = nil
    }
}
