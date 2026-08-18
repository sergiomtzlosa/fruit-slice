import AppKit

final class LeaderboardTable: NSView {
    private let stack = NSStackView()
    private var heightConstraint: NSLayoutConstraint!
    private let rowWidth: CGFloat

    init(width: CGFloat = 560) {
        self.rowWidth = width
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: width),
        ])
        heightConstraint = heightAnchor.constraint(equalToConstant: 100)
        heightConstraint.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(entries: [ScoreEntry], accentCurrent: ScoreEntry? = nil) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(headerRow())

        if entries.isEmpty {
            let empty = Theme.label("No scores yet — slice some fruit and claim the board.",
                                    font: Theme.bodyFont(14),
                                    color: Theme.mutedText,
                                    alignment: .center)
            empty.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
            empty.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(empty)
        } else {
            for (index, entry) in entries.enumerated() {
                let row = makeRow(rank: index + 1, entry: entry,
                                  highlighted: entry.id == accentCurrent?.id)
                stack.addArrangedSubview(row)
            }
        }
        let rows = max(1, entries.count)
        heightConstraint.constant = CGFloat(24 + rows * 34 + 8)
    }

    private func headerRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
        row.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let rank = headerLabel("#", width: 38, alignment: .center)
        let name = headerLabel("PLAYER", width: 250, alignment: .left)
        let level = headerLabel("LEVEL", width: 100, alignment: .center)
        let score = headerLabel("SCORE", width: 110, alignment: .right)
        row.addArrangedSubview(rank)
        row.addArrangedSubview(name)
        row.addArrangedSubview(level)
        row.addArrangedSubview(score)
        return row
    }

    private func headerLabel(_ text: String, width: CGFloat,
                             alignment: NSTextAlignment) -> NSTextField {
        let label = Theme.singleLineLabel(text,
                                          font: Theme.bodyFont(11, weight: .bold),
                                          color: NSColor(calibratedWhite: 1, alpha: 0.4),
                                          alignment: alignment)
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }

    private func makeRow(rank: Int, entry: ScoreEntry, highlighted: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
        container.heightAnchor.constraint(equalToConstant: 34).isActive = true
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        if highlighted {
            container.layer?.backgroundColor = Theme.accent.withAlphaComponent(0.12).cgColor
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let rankColor = rank == 1 ? Theme.warm
            : rank == 2 ? NSColor(calibratedWhite: 0.78, alpha: 1)
            : rank == 3 ? NSColor(calibratedRed: 0.83, green: 0.55, blue: 0.32, alpha: 1)
            : NSColor(calibratedWhite: 1, alpha: 0.55)
        let rankLabel = Theme.singleLineLabel("\(rank)",
                                              font: Theme.bodyFont(16, weight: .bold),
                                              color: rankColor, alignment: .center)
        rankLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true

        let name = Theme.singleLineLabel(entry.playerName,
                                        font: Theme.bodyFont(15, weight: .bold),
                                        color: highlighted ? Theme.accent : .white)
        name.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let level = Theme.singleLineLabel(entry.difficulty.displayName.uppercased(),
                                          font: Theme.bodyFont(10, weight: .bold),
                                          color: Theme.mutedText,
                                          alignment: .center)
        level.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let score = Theme.singleLineLabel("\(entry.score)",
                                          font: NSFont.monospacedDigitSystemFont(ofSize: 17, weight: .bold),
                                          color: .white, alignment: .right)
        score.widthAnchor.constraint(equalToConstant: 110).isActive = true

        row.addArrangedSubview(rankLabel)
        row.addArrangedSubview(name)
        row.addArrangedSubview(level)
        row.addArrangedSubview(score)
        return container
    }
}
