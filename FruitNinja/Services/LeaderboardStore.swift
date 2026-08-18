import Foundation

struct ScoreEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var playerName: String
    let score: Int
    let difficulty: Difficulty
    let date: Date
    let maxCombo: Int
    let fruitsSliced: Int
    let accuracy: Double

    init(id: UUID = UUID(), playerName: String, score: Int, difficulty: Difficulty,
         date: Date = Date(), maxCombo: Int, fruitsSliced: Int, accuracy: Double) {
        self.id = id
        self.playerName = playerName
        self.score = score
        self.difficulty = difficulty
        self.date = date
        self.maxCombo = maxCombo
        self.fruitsSliced = fruitsSliced
        self.accuracy = accuracy
    }
}

private struct LeaderboardFile: Codable {
    var version: Int
    var entries: [ScoreEntry]
}

final class LeaderboardStore {
    private(set) var entries: [ScoreEntry] = []
    private let fileURL: URL
    private let maxStoredEntries = 200

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? LeaderboardStore.defaultFileURL()
        load()
    }

    static func defaultFileURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let bundleID = Bundle.main.bundleIdentifier ?? "com.sid.fruitslice"
        let directory = base.appendingPathComponent(bundleID, isDirectory: true)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("leaderboard.json")
    }

    func record(_ entry: ScoreEntry) {
        entries.append(entry)
        entries.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.date > rhs.date
        }
        if entries.count > maxStoredEntries {
            entries.removeLast(entries.count - maxStoredEntries)
        }
        save()
    }

    /// Top five distinct players. Each player appears once with their best score.
    func topPlayers(limit: Int = 5, difficulty: Difficulty? = nil) -> [ScoreEntry] {
        var bestByName: [String: ScoreEntry] = [:]
        for entry in entries {
            if let difficulty, entry.difficulty != difficulty { continue }
            let key = normalizedName(entry.playerName)
            if let current = bestByName[key] {
                if entry.score > current.score ||
                    (entry.score == current.score && entry.date < current.date) {
                    bestByName[key] = entry
                }
            } else {
                bestByName[key] = entry
            }
        }
        let sorted = bestByName.values.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.maxCombo > rhs.maxCombo
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    func rank(of entryID: UUID, difficulty: Difficulty? = nil) -> Int? {
        let list = topPlayers(limit: 50, difficulty: difficulty)
        guard let index = list.firstIndex(where: { $0.id == entryID }) else { return nil }
        return index + 1
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "player" : trimmed
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let file = try? decoder.decode(LeaderboardFile.self, from: data) {
            entries = file.entries
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let file = LeaderboardFile(version: 1, entries: entries)
        guard let data = try? encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
