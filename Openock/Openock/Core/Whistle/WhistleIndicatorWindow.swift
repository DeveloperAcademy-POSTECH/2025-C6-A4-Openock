import SwiftUI
import AppKit

/// 휘슬 감지 표시를 위한 독립 floating 창
class WhistleIndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 창 설정
        self.isFloatingPanel = true
        self.level = .statusBar  // 메인 창(.floating)보다 위에 표시
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // 창 크기 고정 (새로운 디자인에 맞게 조정)
        self.setContentSize(NSSize(width: 120, height: 50))

        // 초기에는 숨김 (테스트를 위해 주석처리)
         self.orderOut(nil)
    }

    /// 메인 창의 위치를 기준으로 우측 상단 바로 위에 표시
    func updatePosition(for mainWindow: NSWindow, animated: Bool = false) {
        let mainFrame = mainWindow.frame
        let indicatorWidth: CGFloat = 120
        let indicatorHeight: CGFloat = 50

        // 메인 창의 우측 상단 바로 위에 위치 계산
        let indicatorX = mainFrame.maxX - indicatorWidth + 10  // 메인 창 오른쪽 끝에 정렬
        let indicatorY = mainFrame.maxY + 8  // 메인 창 상단에서 8pt 위

        let newOrigin = NSPoint(x: indicatorX, y: indicatorY)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.animator().setFrameOrigin(newOrigin)
            }
        } else {
            // 애니메이션 없이 즉시 이동 - 더 부드러운 추적
            self.setFrameOrigin(newOrigin)
        }
    }

    /// 휘슬 감지 시 표시
    func show() {
        // 창을 최상위로 올리고 표시
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()

        // 3초 후 자동으로 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.hide()
        }
    }

    /// 숨김
    func hide() {
        // parent window에서 제거
        if let parent = self.parent {
            parent.removeChildWindow(self)
        }
        self.orderOut(nil)
    }
}
