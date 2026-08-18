import Foundation
import CoreGraphics
import AppKit

enum FruitKind: String, CaseIterable, Codable {
    case watermelon
    case orange
    case apple
    case pineapple
    case kiwi
    case dragonfruit

    var displayName: String { rawValue.capitalized }

    var textureName: String { "fruit_\(rawValue)" }
    var halfTextureName: String { "fruit_\(rawValue)_half" }

    var displaySize: CGFloat {
        switch self {
        case .watermelon: return 108
        case .orange: return 96
        case .apple: return 100
        case .pineapple: return 112
        case .kiwi: return 90
        case .dragonfruit: return 100
        }
    }

    var juiceColor: NSColor {
        switch self {
        case .watermelon: return NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.36, alpha: 1)
        case .orange: return NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.1, alpha: 1)
        case .apple: return NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.48, alpha: 1)
        case .pineapple: return NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.22, alpha: 1)
        case .kiwi: return NSColor(calibratedRed: 0.65, green: 0.84, blue: 0.32, alpha: 1)
        case .dragonfruit: return NSColor(calibratedRed: 0.98, green: 0.44, blue: 0.75, alpha: 1)
        }
    }
}
