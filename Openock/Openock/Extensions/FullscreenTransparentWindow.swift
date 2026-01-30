import SwiftUI

class FullscreenTransparentHostingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        guard let window = self.window else { return }
        
        // This is the key change: No faulty guard.
        // This code is idempotent, so running it multiple times is safe.

        if let screen = window.screen {
            window.setFrame(screen.frame, display: true)
        }
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        
        // Hide title bar and buttons
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.borderless)
        window.styleMask.remove(.titled)
    }
}

struct FullscreenTransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return FullscreenTransparentHostingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func fullscreenTransparentWindow() -> some View {
        self.background(FullscreenTransparentWindow())
    }
}
