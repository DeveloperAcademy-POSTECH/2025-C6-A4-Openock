//
//  AppDelegate.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

import AppKit
import Combine
import Speech   // ✅ 음성 인식 권한만 사용

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Published var windowDidBecomeKey: Bool = false
  weak var audioPipeline: AudioPipeline?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false

    // ✅ 앱 시작할 때마다 "음성 인식" 권한만 확실히 요청
    requestSpeechPermission()

    // STTView window에 liquid glass 효과 적용
    DispatchQueue.main.async {
      if let window = NSApp.windows.first(where: { $0.title == "" || $0.contentView != nil }) {
        window.applyLiquidGlass()
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      DispatchQueue.main.async {
        self?.windowDidBecomeKey = true
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    print("🛑 [AppDelegate] Application terminating - cleaning up audio resources")

    // MainActor에서 동기적으로 cleanup 수행
    let semaphore = DispatchSemaphore(value: 0)

    DispatchQueue.main.async { [weak self] in
      self?.audioPipeline?.stop()
      print("✅ [AppDelegate] Audio cleanup completed")
      semaphore.signal()
    }

    // cleanup이 완료될 때까지 최대 2초 대기
    _ = semaphore.wait(timeout: .now() + 2.0)
    print("✅ [AppDelegate] Termination cleanup finished")
  }

  // MARK: - Permissions (Speech 만)

  private func requestSpeechPermission() {
    // 여러 번 호출해도 시스템이 알아서 처리 (이미 권한 있으면 팝업 안 뜸)
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          break
        case .denied, .restricted:
          self.showPermissionAlert(
            title: "음성 인식 권한 거부됨",
            message: "음성 인식 권한이 거부되어 자막 기능을 사용할 수 없습니다.\n" +
                     "시스템 설정 > 개인정보 보호 및 보안 > 음성 인식에서 ‘BOSO’ 앱을 허용해주세요."
          )
        case .notDetermined:
          // 특이 케이스 방어용 안내
          self.showPermissionAlert(
            title: "음성 인식 권한 확인 필요",
            message: "음성 인식 권한이 올바르게 설정되지 않았을 수 있습니다.\n" +
                     "시스템 설정 > 개인정보 보호 및 보안 > 음성 인식에서 권한을 확인해주세요."
          )
        @unknown default:
          break
        }
      }
    }
  }

  private func showPermissionAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "확인")
    alert.runModal()
  }
}
