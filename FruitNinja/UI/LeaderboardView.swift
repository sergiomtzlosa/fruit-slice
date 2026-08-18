import AppKit

final class LeaderboardView: NSView {
    var onBack: (() -> Void)?

    private let store: LeaderboardStore
    private let table = LeaderboardTable(width: 560)
    private let filterControl = NSSegmentedControl(
        labels: ["OVERALL", "EASY", "NORMAL", "HARD"],
        trackingMode: .selectOne,
        target: nil,
        action: nil)
    private let subtitle = Theme.singleLineLabel("",
                                                 font: Theme.bodyFont(14),
                                                 color: Theme.mutedText,
                                                 alignment: .center)

    init(store: LeaderboardStore) {
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 0.9).cgColor

        filterControl.target = self
        filterControl.action = #selector(filterChanged)
        filterControl.selectedSegment = 0
        filterControl.segmentStyle = .rounded
        filterControl.font = Theme.bodyFont(12, weight: .bold)
        filterControl.translatesAutoresizingMaskIntoConstraints = false

        let title = Theme.singleLineLabel("TOP 5 PLAYERS",
                                          font: Theme.titleFont(62),
                                          color: .white,
                                          alignment: .center)
        let backButton = FruitButton(title: "Back", style: .secondary)
        backButton.widthAnchor.constraint(equalToConstant: 220).isActive = true
        backButton.onClick = { [weak self] in self?.onBack?() }

        let stack = NSStackView(views: [title, subtitle, filterControl, table, backButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(22, after: subtitle)
        stack.setCustomSpacing(18, after: filterControl)
        stack.setCustomSpacing(26, after: table)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            filterControl.widthAnchor.constraint(equalToConstant: 420),
        ])
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func filterChanged() {
        reload()
    }

    private func reload() {
        let index = filterControl.selectedSegment
        let difficulty: Difficulty?
        if index <= 0 {
            difficulty = nil
            subtitle.stringValue = "Best score per player across all difficulties"
        } else {
            let diff = Difficulty.allCases[min(index - 1, Difficulty.allCases.count - 1)]
            difficulty = diff
            subtitle.stringValue = "Best score per player on \(diff.displayName)"
        }
        let entries = store.topPlayers(limit: 5, difficulty: difficulty)
        table.update(entries: entries)
    }
}
