#if DEBUG
import AppKit
import CoreGraphics
import SpriteKit

/// Development-only visual harness. Enabled by setting
/// `FRUITSLICE_CAPTURE_DIR` and optionally `FRUITSLICE_AUTOPLAY=mouse`.
/// It captures the app window without requiring Screen Recording permission
/// from an external tool.
enum DebugCapture {
    static let directory: URL? = {
        guard let path = ProcessInfo.processInfo.environment["FRUITSLICE_CAPTURE_DIR"],
              !path.isEmpty else { return nil }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(path, isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var enabled: Bool { directory != nil }

    static func schedule(delay: TimeInterval, _ action: @escaping () -> Void) {
        guard enabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    static func captureWindow(name: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else {
            NSLog("DebugCapture: no visible window for \(name)")
            return
        }
        var image: CGImage?
        if window.windowNumber > 0 {
            image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming, .bestResolution])
        }
        if image == nil, let view = window.contentView {
            image = renderView(view)
        }
        guard let image else {
            NSLog("DebugCapture: could not capture \(name)")
            return
        }
        write(image, name: name)
    }

    /// Renders the AppKit hierarchy directly into a bitmap. This does not need
    /// Screen Recording access and reliably captures menu and overlay screens.
    static func captureInterface(name: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView else {
            NSLog("DebugCapture: no visible window for \(name)")
            return
        }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let image = renderView(view) else {
            NSLog("DebugCapture: could not render interface \(name)")
            return
        }
        write(image, name: name)
    }

    private static func renderView(_ view: NSView) -> CGImage? {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        return rep.cgImage
    }

    private static func write(_ image: CGImage, name: String) {
        guard let directory else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            NSLog("DebugCapture wrote \(url.path)")
        } catch {
            NSLog("DebugCapture write failed for \(url.path): \(error.localizedDescription)")
        }
    }

    static func captureScene(_ scene: SKScene, name: String) {
        guard let view = scene.view else { return }
        let size = view.bounds.size
        guard let texture = view.texture(from: scene,
                                        crop: CGRect(origin: .zero, size: size)) else { return }
        write(texture.cgImage(), name: name)
    }
}
#endif
