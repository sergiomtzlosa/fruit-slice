import AppKit

final class SettingsView: NSView, NSTextFieldDelegate {
    var onBack: (() -> Void)?
    var onAudioSettingsChanged: (() -> Void)?
    var onMouseModeChanged: ((Bool) -> Void)?

    private let settings: SettingsStore
    private let leaderboard: LeaderboardStore
    private let nameField = NSTextField()
    private let musicSlider = NSSlider()
    private let sfxSlider = NSSlider()
    private let musicValue = Theme.singleLineLabel("", font: Theme.bodyFont(12, weight: .bold),
                                                   color: Theme.mutedText, alignment: .right)
    private let sfxValue = Theme.singleLineLabel("", font: Theme.bodyFont(12, weight: .bold),
                                                 color: Theme.mutedText, alignment: .right)

    init(settings: SettingsStore, leaderboard: LeaderboardStore) {
        self.settings = settings
        self.leaderboard = leaderboard
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 0.92).cgColor

        let title = Theme.singleLineLabel("SETTINGS",
                                          font: Theme.titleFont(62),
                                          color: .white,
                                          alignment: .center)
        let caption = Theme.singleLineLabel("Tune the dojo to your liking.",
                                            font: Theme.bodyFont(14),
                                            color: Theme.mutedText,
                                            alignment: .center)

        nameField.stringValue = settings.playerName
        nameField.font = Theme.bodyFont(15, weight: .bold)
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.isBezeled = true
        nameField.bezelStyle = .roundedBezel
        nameField.focusRingType = .exterior
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(nameCommitted)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        nameField.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let nameRow = makeRow(label: "PLAYER NAME", control: nameField)

        let audioHeading = sectionHeading("AUDIO")
        musicSlider.minValue = 0
        musicSlider.maxValue = 1
        musicSlider.doubleValue = Double(settings.musicVolume)
        musicSlider.isContinuous = true
        musicSlider.target = self
        musicSlider.action = #selector(musicChanged)
        musicSlider.translatesAutoresizingMaskIntoConstraints = false
        musicSlider.widthAnchor.constraint(equalToConstant: 230).isActive = true
        let musicRow = makeRow(label: "MUSIC", control: musicSlider, trailing: musicValue)
        updateVolumeLabels()

        sfxSlider.minValue = 0
        sfxSlider.maxValue = 1
        sfxSlider.doubleValue = Double(settings.sfxVolume)
        sfxSlider.isContinuous = true
        sfxSlider.target = self
        sfxSlider.action = #selector(sfxChanged)
        sfxSlider.translatesAutoresizingMaskIntoConstraints = false
        sfxSlider.widthAnchor.constraint(equalToConstant: 230).isActive = true
        let sfxRow = makeRow(label: "SOUND FX", control: sfxSlider, trailing: sfxValue)

        let mouseCheckbox = NSButton(checkboxWithTitle: "Use mouse instead of camera",
                                     target: self, action: #selector(mouseModeChanged))
        mouseCheckbox.state = settings.useMouseMode ? .on : .off
        mouseCheckbox.font = Theme.bodyFont(14)
        mouseCheckbox.contentTintColor = Theme.accent
        mouseCheckbox.translatesAutoresizingMaskIntoConstraints = false
        let mouseHint = Theme.label(
            "Mouse Blade skips camera tracking. Useful for testing or if camera access is unavailable.",
            font: Theme.bodyFont(12),
            color: Theme.mutedText)
        mouseHint.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let cameraButton = FruitButton(title: "Open Camera Permissions", style: .secondary, height: 38)
        cameraButton.widthAnchor.constraint(equalToConstant: 240).isActive = true
        cameraButton.onClick = {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }

        let resetButton = FruitButton(title: "Reset Leaderboard", style: .danger, height: 38)
        resetButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        resetButton.onClick = { [weak self] in self?.confirmReset() }

        let actionRow = NSStackView(views: [cameraButton, resetButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 12
        actionRow.alignment = .centerY
        actionRow.distribution = .fillEqually
        actionRow.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let backButton = FruitButton(title: "Back", style: .primary, height: 44)
        backButton.widthAnchor.constraint(equalToConstant: 240).isActive = true
        backButton.onClick = { [weak self] in self?.onBack?() }

        let separator1 = Theme.separator()
        separator1.widthAnchor.constraint(equalToConstant: 500).isActive = true
        let separator2 = Theme.separator()
        separator2.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView(views: [
            title, caption, nameRow, separator1, audioHeading,
            musicRow, sfxRow, separator2, mouseCheckbox, mouseHint,
            actionRow, backButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(24, after: caption)
        stack.setCustomSpacing(18, after: nameRow)
        stack.setCustomSpacing(14, after: audioHeading)
        stack.setCustomSpacing(20, after: sfxRow)
        stack.setCustomSpacing(4, after: mouseCheckbox)
        stack.setCustomSpacing(22, after: mouseHint)
        stack.setCustomSpacing(18, after: actionRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(label: String, control: NSView,
                         trailing: NSTextField? = nil) -> NSView {
        let title = Theme.singleLineLabel(label,
                                          font: Theme.bodyFont(11, weight: .bold),
                                          color: NSColor(calibratedWhite: 1, alpha: 0.5),
                                          alignment: .left)
        title.widthAnchor.constraint(equalToConstant: 130).isActive = true
        var views: [NSView] = [title, control]
        if let trailing {
            trailing.widthAnchor.constraint(equalToConstant: 48).isActive = true
            views.append(trailing)
        }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        return row
    }

    private func sectionHeading(_ text: String) -> NSTextField {
        let label = Theme.singleLineLabel(text,
                                          font: Theme.bodyFont(11, weight: .bold),
                                          color: Theme.accent,
                                          alignment: .left)
        label.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: Theme.bodyFont(11, weight: .bold),
            .foregroundColor: Theme.accent,
            .kern: 2.6,
        ])
        return label
    }

    private func updateVolumeLabels() {
        musicValue.stringValue = "\(Int((settings.musicVolume * 100).rounded()))%"
        sfxValue.stringValue = "\(Int((settings.sfxVolume * 100).rounded()))%"
    }

    @objc private func nameCommitted() {
        settings.playerName = nameField.stringValue
        nameField.stringValue = settings.playerName
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        nameCommitted()
    }

    @objc private func musicChanged() {
        settings.musicVolume = Float(musicSlider.doubleValue)
        updateVolumeLabels()
        onAudioSettingsChanged?()
    }

    @objc private func sfxChanged() {
        settings.sfxVolume = Float(sfxSlider.doubleValue)
        updateVolumeLabels()
        onAudioSettingsChanged?()
    }

    @objc private func mouseModeChanged(_ sender: NSButton) {
        settings.useMouseMode = sender.state == .on
        onMouseModeChanged?(settings.useMouseMode)
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Reset the leaderboard?"
        alert.informativeText = "This removes every saved score on this Mac. It cannot be undone."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            leaderboard.clear()
        }
    }
}
