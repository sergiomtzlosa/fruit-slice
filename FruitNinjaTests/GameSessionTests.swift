import XCTest
@testable import FruitNinja

final class GameSessionTests: XCTestCase {
    func testStartsWithThreeLives() {
        let session = GameSession(difficulty: .normal)
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.score, 0)
        XCTAssertFalse(session.isGameOver)
    }

    func testSlicesScoreAndTrackStats() {
        let session = GameSession(difficulty: .normal)
        session.recordSlice(points: 10)
        session.recordSlice(points: 15)
        session.noteCombo(3)
        XCTAssertEqual(session.score, 25)
        XCTAssertEqual(session.fruitsSliced, 2)
        XCTAssertEqual(session.maxCombo, 3)
    }

    func testExtraLifeAtDifficultythresholds() {
        let easy = GameSession(difficulty: .easy)
        XCTAssertEqual(easy.recordSlice(points: 99), 0)
        XCTAssertEqual(easy.lives, 3)
        XCTAssertEqual(easy.recordSlice(points: 1), 1)
        XCTAssertEqual(easy.lives, 4)
        XCTAssertEqual(easy.nextExtraLifeScore, 300)

        let normal = GameSession(difficulty: .normal)
        XCTAssertEqual(normal.recordSlice(points: 149), 0)
        XCTAssertEqual(normal.recordSlice(points: 1), 1)
        XCTAssertEqual(normal.lives, 4)
        XCTAssertEqual(normal.nextExtraLifeScore, 400)

        let hard = GameSession(difficulty: .hard)
        XCTAssertEqual(hard.recordSlice(points: 199), 0)
        XCTAssertEqual(hard.recordSlice(points: 1), 1)
        XCTAssertEqual(hard.lives, 4)
        XCTAssertEqual(hard.nextExtraLifeScore, 500)
    }

    func testLivesAreCappedAtFive() {
        let session = GameSession(difficulty: .easy)
        XCTAssertEqual(session.recordSlice(points: 100), 1)
        XCTAssertEqual(session.lives, 4)
        XCTAssertEqual(session.recordSlice(points: 200), 1)
        XCTAssertEqual(session.lives, 5)
        XCTAssertEqual(session.recordSlice(points: 200), 0)
        XCTAssertEqual(session.lives, 5)
        XCTAssertEqual(session.nextExtraLifeScore, 700)
    }

    func testOneLargeJumpCanAwardMultipleLivesButRespectsCap() {
        let session = GameSession(difficulty: .easy)
        let awarded = session.recordSlice(points: 1000)
        XCTAssertEqual(awarded, 2)
        XCTAssertEqual(session.lives, 5)
        XCTAssertEqual(session.nextExtraLifeScore, 1100)
    }

    func testMissedFruitCostsLifeAndEndsGame() {
        let session = GameSession(difficulty: .normal)
        XCTAssertFalse(session.recordMiss())
        XCTAssertEqual(session.lives, 2)
        XCTAssertFalse(session.recordMiss())
        XCTAssertEqual(session.lives, 1)
        XCTAssertTrue(session.recordMiss())
        XCTAssertEqual(session.lives, 0)
        XCTAssertTrue(session.isGameOver)
        XCTAssertEqual(session.fruitsMissed, 3)
    }

    func testSlicedBombCostsLifeAndEndsGame() {
        let session = GameSession(difficulty: .normal)
        XCTAssertFalse(session.recordBombSlice())
        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.bombsSliced, 1)
        XCTAssertFalse(session.recordBombSlice())
        XCTAssertTrue(session.recordBombSlice())
        XCTAssertTrue(session.isGameOver)
        XCTAssertEqual(session.lives, 0)
    }

    func testNoScoreAfterGameOver() {
        let session = GameSession(difficulty: .normal)
        session.recordBombSlice()
        session.recordBombSlice()
        session.recordBombSlice()
        XCTAssertTrue(session.isGameOver)
        XCTAssertEqual(session.recordSlice(points: 50), 0)
        XCTAssertEqual(session.score, 0)
        XCTAssertEqual(session.recordMiss(), true)
    }

    func testSummaryAccuracy() {
        let session = GameSession(difficulty: .hard)
        session.recordSlice(points: 10)
        session.recordSlice(points: 10)
        session.recordMiss()
        session.recordMiss()
        let summary = session.makeSummary()
        XCTAssertEqual(summary.score, 20)
        XCTAssertEqual(summary.fruitsSliced, 2)
        XCTAssertEqual(summary.fruitsMissed, 2)
        XCTAssertEqual(summary.accuracy, 0.5, accuracy: 0.0001)
    }
}
