import AppKit
import SpriteKit

enum Theme {
    static let accent = NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.82, alpha: 1)
    static let accentDark = NSColor(calibratedRed: 0.11, green: 0.72, blue: 0.61, alpha: 1)
    static let warm = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.32, alpha: 1)
    static let danger = NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.46, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.025, green: 0.07, blue: 0.1, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 1, alpha: 0.66)

    static func titleFont(_ size: CGFloat) -> NSFont {
        NSFont(name: "AvenirNextCondensed-Heavy", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: .heavy)
    }

    static func bodyFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: weight == .bold ? "AvenirNext-Bold" : "AvenirNext-Medium", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func label(_ text: String,
                      font: NSFont,
                      color: NSColor,
                      alignment: NSTextAlignment = .left) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.alignment = alignment
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    static func singleLineLabel(_ text: String,
                                font: NSFont,
                                color: NSColor,
                                alignment: NSTextAlignment = .left) -> NSTextField {
        let field = label(text, font: font, color: color, alignment: alignment)
        field.lineBreakMode = .byClipping
        field.maximumNumberOfLines = 1
        return field
    }

    static func separator(color: NSColor = NSColor(calibratedWhite: 1, alpha: 0.1)) -> NSView {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = color.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

enum FruitButtonStyle {
    case primary
    case secondary
    case danger
}

final class FruitButton: NSButton {
    var onClick: (() -> Void)?

    init(title: String, style: FruitButtonStyle = .secondary, height: CGFloat = 44) {
        super.init(frame: .zero)
        self.title = title
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.cornerRadius = 12
        self.layer?.masksToBounds = true
        self.translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true

        let color: NSColor
        let textColor: NSColor
        switch style {
        case .primary:
            color = Theme.accent
            textColor = NSColor(calibratedRed: 0.02, green: 0.12, blue: 0.09, alpha: 1)
        case .secondary:
            color = NSColor(calibratedWhite: 1, alpha: 0.08)
            textColor = .white
        case .danger:
            color = NSColor(calibratedRed: 0.8, green: 0.2, blue: 0.26, alpha: 0.35)
            textColor = Theme.danger
        }
        layer?.backgroundColor = color.cgColor
        if style == .secondary {
            layer?.borderWidth = 1
            layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.15).cgColor
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributedTitle = NSAttributedString(string: title.uppercased(), attributes: [
            .font: Theme.bodyFont(style == .primary ? 18 : 15, weight: .bold),
            .foregroundColor: textColor,
            .kern: 1.2,
            .paragraphStyle: paragraph,
        ])
        target = self
        action = #selector(clicked)
        setButtonType(.momentaryChange)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func clicked() {
        onClick?()
    }
}

final class TrackingSKView: SKView {
    var onMousePoint: ((CGPoint?) -> Void)?
    private var currentTrackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let currentTrackingArea {
            removeTrackingArea(currentTrackingArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        currentTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        onMousePoint?(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        onMousePoint?(convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        onMousePoint?(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        onMousePoint?(nil)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
