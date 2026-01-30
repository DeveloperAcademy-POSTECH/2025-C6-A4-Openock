import SwiftUI
import AppKit

struct GIFView: NSViewRepresentable {
    let name: String
    var loops: Bool = true
    var onFinished: (() -> Void)?

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        loadGIF(into: imageView, context: context)

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        // name이 변경된 경우에만 다시 로드
        if context.coordinator.currentName != name {
            loadGIF(into: nsView, context: context)
        }
    }

    private func loadGIF(into imageView: NSImageView, context: Context) {
        context.coordinator.currentName = name

        if let url = Bundle.main.url(forResource: name, withExtension: "gif"),
           let image = NSImage(contentsOf: url) {
            imageView.image = image
            imageView.animates = true

            if !loops {
                scheduleFinishCallback(for: image)
            }
        }
    }

    private func scheduleFinishCallback(for image: NSImage) {
        guard let bitmapRep = image.representations.first as? NSBitmapImageRep else { return }

        let frameCount = bitmapRep.value(forProperty: .frameCount) as? Int ?? 1
        var totalDuration: Double = 0

        for i in 0..<frameCount {
            bitmapRep.setProperty(.currentFrame, withValue: i)
            let frameDuration = bitmapRep.value(forProperty: .currentFrameDuration) as? Double ?? 0.1
            totalDuration += frameDuration
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            onFinished?()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var currentName: String = ""
    }
}
