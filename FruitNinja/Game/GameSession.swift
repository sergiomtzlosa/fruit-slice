import Foundation

struct GameSummary {
    let difficulty: Difficulty
    let score: Int
    let maxCombo: Int
    let fruitsSliced: Int
    let fruitsMissed: Int
    let bombsSliced: Int
    let duration: TimeInterval
    let date: Date

    var accuracy: Double {
        let attempts = fruitsSliced + fruitsMissed
        guard attempts > 0 else { return 0 }
        return Double(fruitsSliced) / Double(attempts)
    }
}

/// Deterministic game rules: scoring, lives, extra-life milestones and end condition.
final class GameSession {
    let difficulty: Difficulty
    static let startingLives = 3

    private(set) var score = 0
    private(set) var lives = GameSession.startingLives
    private(set) var nextExtraLifeScore: Int
    private(set) var fruitsSliced = 0
    private(set) var fruitsMissed = 0
    private(set) var bombsSliced = 0
    private(set) var maxCombo = 0
    private(set) var isGameOver = false
    private let startedAt = Date()

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.nextExtraLifeScore = difficulty.firstExtraLife
    }

    /// Returns how many extra lives were awarded by this point gain.
    @discardableResult
    func recordSlice(points: Int) -> Int {
        guard !isGameOver else { return 0 }
        fruitsSliced += 1
        let safePoints = max(0, points)
        score += safePoints
        return awardExtraLivesIfNeeded()
    }

    @discardableResult
    func recordMiss() -> Bool {
        guard !isGameOver else { return true }
        fruitsMissed += 1
        lives = max(0, lives - 1)
        if lives == 0 {
            isGameOver = true
        }
        return isGameOver
    }

    @discardableResult
    func recordBombSlice() -> Bool {
        guard !isGameOver else { return true }
        bombsSliced += 1
        lives = max(0, lives - 1)
        if lives == 0 {
            isGameOver = true
        }
        return isGameOver
    }

    func noteCombo(_ combo: Int) {
        maxCombo = max(maxCombo, combo)
    }

    private func awardExtraLivesIfNeeded() -> Int {
        var awarded = 0
        while score >= nextExtraLifeScore {
            if lives < difficulty.maxLives {
                lives += 1
                awarded += 1
            }
            nextExtraLifeScore += difficulty.extraLifeStep
        }
        return awarded
    }

    func makeSummary() -> GameSummary {
        GameSummary(
            difficulty: difficulty,
            score: score,
            maxCombo: maxCombo,
            fruitsSliced: fruitsSliced,
            fruitsMissed: fruitsMissed,
            bombsSliced: bombsSliced,
            duration: Date().timeIntervalSince(startedAt),
            date: Date()
        )
    }
}
