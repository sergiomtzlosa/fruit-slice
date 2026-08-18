import AppKit

final class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Fruit Slice"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 1)
        window.contentMinSize = NSSize(width: 1000, height: 650)
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = false
        window.center()
        window.setFrameAutosaveName("FruitSliceMainWindow")

        let root = RootViewController()
        window.contentViewController = root
        self.init(window: window)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(root.view)
    }
}
