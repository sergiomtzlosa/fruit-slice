import XCTest
@testable import FruitNinja

final class DifficultyTests: XCTestCase {
    func testAllDifficultiesExistInOrder() {
        XCTAssertEqual(Difficulty.allCases, [.easy, .normal, .hard])
    }

    func testSpawnIntervalsGetFasterWithDifficulty() {
        XCTAssertGreaterThan(Difficulty.easy.spawnInterval.lowerBound,
                             Difficulty.normal.spawnInterval.lowerBound)
        XCTAssertGreaterThan(Difficulty.normal.spawnInterval.lowerBound,
                             Difficulty.hard.spawnInterval.lowerBound)
        XCTAssertGreaterThan(Difficulty.easy.spawnInterval.upperBound,
                             Difficulty.normal.spawnInterval.upperBound)
        XCTAssertGreaterThan(Difficulty.normal.spawnInterval.upperBound,
                             Difficulty.hard.spawnInterval.upperBound)
    }

    func testSpeedAndBombChanceIncreaseWithDifficulty() {
        XCTAssertLessThan(Difficulty.easy.speedScale, Difficulty.normal.speedScale)
        XCTAssertLessThan(Difficulty.normal.speedScale, Difficulty.hard.speedScale)
        XCTAssertLessThan(Difficulty.easy.bombChance, Difficulty.normal.bombChance)
        XCTAssertLessThan(Difficulty.normal.bombChance, Difficulty.hard.bombChance)
    }

    func testExtraLifeThresholdsAndCaps() {
        XCTAssertLessThan(Difficulty.easy.firstExtraLife, Difficulty.normal.firstExtraLife)
        XCTAssertLessThan(Difficulty.normal.firstExtraLife, Difficulty.hard.firstExtraLife)
        XCTAssertLessThan(Difficulty.easy.extraLifeStep, Difficulty.normal.extraLifeStep)
        XCTAssertLessThan(Difficulty.normal.extraLifeStep, Difficulty.hard.extraLifeStep)
        for difficulty in Difficulty.allCases {
            XCTAssertEqual(difficulty.maxLives, 5)
        }
    }

    func testWaveSizes() {
        XCTAssertEqual(Difficulty.easy.fruitsPerWave, 1...1)
        XCTAssertEqual(Difficulty.normal.fruitsPerWave, 1...2)
        XCTAssertEqual(Difficulty.hard.fruitsPerWave, 2...3)
    }
}
