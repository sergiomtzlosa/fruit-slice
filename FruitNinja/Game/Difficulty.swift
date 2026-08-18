import Foundation
import CoreGraphics

enum Difficulty: String, CaseIterable, Codable, Equatable {
    case easy
    case normal
    case hard

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    var tagline: String {
        switch self {
        case .easy: return "A gentle harvest"
        case .normal: return "The classic challenge"
        case .hard: return "Master of the blade"
        }
    }

    var spawnInterval: ClosedRange<Double> {
        switch self {
        case .easy: return 1.4...2.2
        case .normal: return 0.9...1.5
        case .hard: return 0.55...0.95
        }
    }

    var fruitsPerWave: ClosedRange<Int> {
        switch self {
        case .easy: return 1...1
        case .normal: return 1...2
        case .hard: return 2...3
        }
    }

    var speedScale: CGFloat {
        switch self {
        case .easy: return 0.8
        case .normal: return 1.0
        case .hard: return 1.3
        }
    }

    var bombChance: Double {
        switch self {
        case .easy: return 0.05
        case .normal: return 0.12
        case .hard: return 0.20
        }
    }

    var firstExtraLife: Int {
        switch self {
        case .easy: return 100
        case .normal: return 150
        case .hard: return 200
        }
    }

    var extraLifeStep: Int {
        switch self {
        case .easy: return 200
        case .normal: return 250
        case .hard: return 300
        }
    }

    var maxLives: Int { 5 }

    var maxOnscreenFruits: Int {
        switch self {
        case .easy: return 3
        case .normal: return 5
        case .hard: return 8
        }
    }

    func randomSpawnInterval() -> TimeInterval {
        Double.random(in: spawnInterval)
    }

    func randomFruitCount() -> Int {
        Int.random(in: fruitsPerWave)
    }
}
