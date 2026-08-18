import AppKit

final class MenuView: NSView {
    var onPlay: (() -> Void)?
    var onLeaderboard: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDifficultyChanged: ((Difficulty) -> Void)?

    private let difficultyControl: NSSegmentedControl
    private let taglineLabel: NSTextField
    private var difficulty: Difficulty

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.difficultyControl = NSSegmentedControl(
            labels: Difficulty.allCases.map { $0.displayName.uppercased() },
            trackingMode: .selectOne,
            target: nil,
            action: nil)
        self.taglineLabel = Theme.singleLineLabel(difficulty.tagline,
                                                  font: Theme.bodyFont(15),
                                                  color: Theme.mutedText,
                                                  alignment: .center)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.34).cgColor

        difficultyControl.target = self
        difficultyControl.action = #selector(difficultyChanged)
        difficultyControl.selectedSegment = Difficulty.allCases.firstIndex(of: difficulty) ?? 2
        difficultyControl.segmentStyle = .rounded
        difficultyControl.font = Theme.bodyFont(12, weight: .bold)
        difficultyControl.translatesAutoresizingMaskIntoConstraints = false
        difficultyControl.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let title = Theme.singleLineLabel("FRUIT SLICE",
                                          font: Theme.titleFont(84),
                                          color: .white,
                                          alignment: .center)
        let caption = Theme.singleLineLabel("CAMERA. FINGERTIP. FRUIT.",
                                            font: Theme.bodyFont(13, weight: .bold),
                                            color: Theme.accent,
                                            alignment: .center)
        caption.attributedStringValue = NSAttributedString(
            string: "CAMERA. FINGERTIP. FRUIT.",
            attributes: [
                .font: Theme.bodyFont(13, weight: .bold),
                .foregroundColor: Theme.accent,
                .kern: 3.2,
            ])

        let instructions = Theme.label(
            "Swipe your index finger through the fruit. Don't slice bombs. Don't miss fruit. Reach score milestones to earn extra lives.",
            font: Theme.bodyFont(14),
            color: Theme.mutedText,
            alignment: .center)
        instructions.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let difficultyCaption = Theme.singleLineLabel("DIFFICULTY",
                                                      font: Theme.bodyFont(11, weight: .bold),
                                                      color: NSColor(calibratedWhite: 1, alpha: 0.45),
                                                      alignment: .center)
        difficultyCaption.attributedStringValue = NSAttributedString(
            string: "DIFFICULTY",
            attributes: [
                .font: Theme.bodyFont(11, weight: .bold),
                .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.45),
                .kern: 2.4,
            ])

        let playButton = FruitButton(title: "Play", style: .primary, height: 54)
        playButton.widthAnchor.constraint(equalToConstant: 300).isActive = true
        playButton.keyEquivalent = "\r"
        playButton.onClick = { [weak self] in self?.onPlay?() }

        let leaderboardButton = FruitButton(title: "Leaderboard", style: .secondary)
        leaderboardButton.widthAnchor.constraint(equalToConstant: 300).isActive = true
        leaderboardButton.onClick = { [weak self] in self?.onLeaderboard?() }

        let settingsButton = FruitButton(title: "Settings", style: .secondary)
        settingsButton.widthAnchor.constraint(equalToConstant: 300).isActive = true
        settingsButton.onClick = { [weak self] in self?.onSettings?() }

        let stack = NSStackView(views: [
            title, caption, instructions,
            difficultyCaption, difficultyControl, taglineLabel,
            playButton, leaderboardButton, settingsButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(18, after: caption)
        stack.setCustomSpacing(28, after: instructions)
        stack.setCustomSpacing(6, after: difficultyCaption)
        stack.setCustomSpacing(22, after: taglineLabel)
        stack.setCustomSpacing(8, after: playButton)
        stack.setCustomSpacing(8, after: leaderboardButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
            difficultyControl.widthAnchor.constraint(equalToConstant: 360),
        ])

        let footer = Theme.singleLineLabel(
            "3 LIVES TO START  •  EXTRA LIVES AT SCORE MILESTONES  •  TOP 5 LEADERBOARD",
            font: Theme.bodyFont(11, weight: .bold),
            color: NSColor(calibratedWhite: 1, alpha: 0.38),
            alignment: .center)
        addSubview(footer)
        NSLayoutConstraint.activate([
            footer.centerXAnchor.constraint(equalTo: centerXAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func difficultyChanged() {
        let index = difficultyControl.selectedSegment
        guard index >= 0, index < Difficulty.allCases.count else { return }
        difficulty = Difficulty.allCases[index]
        taglineLabel.stringValue = difficulty.tagline
        onDifficultyChanged?(difficulty)
    }
}
