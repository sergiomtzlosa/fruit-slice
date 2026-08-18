import AppKit

final class GameOverView: NSView {
    var onReplay: (() -> Void)?
    var onMenu: (() -> Void)?

    private let summary: GameSummary

    init(summary: GameSummary, entries: [ScoreEntry], currentEntry: ScoreEntry?, rank: Int?) {
        self.summary = summary
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 0.86).cgColor

        let title = Theme.singleLineLabel("GAME OVER",
                                          font: Theme.titleFont(58),
                                          color: .white,
                                          alignment: .center)
        let scoreCaption = Theme.singleLineLabel("YOUR SCORE",
                                                 font: Theme.bodyFont(11, weight: .bold),
                                                 color: NSColor(calibratedWhite: 1, alpha: 0.5),
                                                 alignment: .center)
        scoreCaption.attributedStringValue = NSAttributedString(string: "YOUR SCORE", attributes: [
            .font: Theme.bodyFont(11, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.5),
            .kern: 2.5,
        ])
        let score = Theme.singleLineLabel("\(summary.score)",
                                          font: Theme.titleFont(86),
                                          color: Theme.accent,
                                          alignment: .center)
        let accuracy = Int((summary.accuracy * 100).rounded())
        let stats = Theme.singleLineLabel(
            "\(summary.fruitsSliced) FRUIT  •  \(summary.maxCombo)× MAX COMBO  •  \(accuracy)% ACCURACY  •  \(summary.difficulty.displayName.uppercased())",
            font: Theme.bodyFont(12, weight: .bold),
            color: Theme.mutedText,
            alignment: .center)

        let rankText: String
        if let rank, rank <= 5 {
            rankText = "NEW #\(rank) ON THE \(summary.difficulty.displayName.uppercased()) BOARD"
        } else {
            let playerName = currentEntry?.playerName.uppercased() ?? "PLAYER"
            rankText = "SCORE SAVED FOR \(playerName)"
        }
        let rankLabel = Theme.singleLineLabel(rankText,
                                              font: Theme.bodyFont(12, weight: .bold),
                                              color: rank != nil ? Theme.warm : Theme.mutedText,
                                              alignment: .center)

        let table = LeaderboardTable(width: 560)
        table.update(entries: entries, accentCurrent: currentEntry)

        let replay = FruitButton(title: "Play Again", style: .primary, height: 46)
        replay.widthAnchor.constraint(equalToConstant: 240).isActive = true
        replay.keyEquivalent = "\r"
        replay.onClick = { [weak self] in self?.onReplay?() }

        let menu = FruitButton(title: "Main Menu", style: .secondary, height: 46)
        menu.widthAnchor.constraint(equalToConstant: 240).isActive = true
        menu.onClick = { [weak self] in self?.onMenu?() }

        let buttons = NSStackView(views: [replay, menu])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 14

        let stack = NSStackView(views: [
            title, scoreCaption, score, stats, rankLabel, table, buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(2, after: title)
        stack.setCustomSpacing(0, after: scoreCaption)
        stack.setCustomSpacing(16, after: score)
        stack.setCustomSpacing(14, after: stats)
        stack.setCustomSpacing(16, after: rankLabel)
        stack.setCustomSpacing(22, after: table)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
