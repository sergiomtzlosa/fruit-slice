import XCTest
@testable import FruitNinja

final class LeaderboardStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FruitNinjaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("leaderboard.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func entry(_ name: String, score: Int,
                       difficulty: Difficulty = .normal,
                       date: Date = Date(), combo: Int = 1) -> ScoreEntry {
        ScoreEntry(playerName: name,
                   score: score,
                   difficulty: difficulty,
                   date: date,
                   maxCombo: combo,
                   fruitsSliced: score / 10,
                   accuracy: 0.8)
    }

    func testTopFiveSortedByScore() {
        let store = LeaderboardStore(fileURL: fileURL)
        for (index, score) in [80, 210, 40, 190, 120, 310].enumerated() {
            store.record(entry("Player\(index)", score: score))
        }
        let top = store.topPlayers()
        XCTAssertEqual(top.map(\.score), [310, 210, 190, 120, 80])
    }

    func testDuplicatePlayerNamesKeepBestScore() {
        let store = LeaderboardStore(fileURL: fileURL)
        store.record(entry("Alice", score: 80))
        store.record(entry("alice", score: 240))
        store.record(entry("  ALICE ", score: 140))
        store.record(entry("Bob", score: 90))
        let top = store.topPlayers()
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top.first?.playerName, "alice")
        XCTAssertEqual(top.first?.score, 240)
        XCTAssertEqual(top.last?.playerName, "Bob")
    }

    func testDifficultyFiltering() {
        let store = LeaderboardStore(fileURL: fileURL)
        store.record(entry("A", score: 100, difficulty: .easy))
        store.record(entry("B", score: 100, difficulty: .normal))
        store.record(entry("C", score: 100, difficulty: .hard))
        XCTAssertEqual(store.topPlayers(difficulty: .normal).map(\.playerName), ["B"])
        XCTAssertEqual(store.topPlayers().count, 3)
    }

    func testPersistenceReload() throws {
        let store = LeaderboardStore(fileURL: fileURL)
        store.record(entry("Persisted", score: 321, difficulty: .hard, combo: 4))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let reloaded = LeaderboardStore(fileURL: fileURL)
        let top = reloaded.topPlayers()
        XCTAssertEqual(top.count, 1)
        XCTAssertEqual(top.first?.playerName, "Persisted")
        XCTAssertEqual(top.first?.score, 321)
        XCTAssertEqual(top.first?.maxCombo, 4)
    }

    func testRankFindsEntry() {
        let store = LeaderboardStore(fileURL: fileURL)
        let low = entry("Low", score: 10)
        let high = entry("High", score: 500)
        store.record(low)
        store.record(high)
        XCTAssertEqual(store.rank(of: high.id), 1)
        XCTAssertEqual(store.rank(of: low.id), 2)
        XCTAssertNil(store.rank(of: UUID()))
    }

    func testClearRemovesEntries() {
        let store = LeaderboardStore(fileURL: fileURL)
        store.record(entry("A", score: 10))
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.topPlayers().isEmpty)
        let reloaded = LeaderboardStore(fileURL: fileURL)
        XCTAssertTrue(reloaded.topPlayers().isEmpty)
    }

    func testStoredEntriesAreCapped() {
        let store = LeaderboardStore(fileURL: fileURL)
        for score in 1...250 {
            store.record(entry("Player\(score)", score: score))
        }
        XCTAssertEqual(store.entries.count, 200)
        XCTAssertEqual(store.entries.first?.score, 250)
        XCTAssertEqual(store.entries.last?.score, 51)
    }
}
