import Foundation
import CoreGraphics

enum SliceDetector {
    /// The blade must move at least this fast (points per second) to slice.
    static let minimumSliceSpeed: CGFloat = 620

    static func distance(from point: CGPoint, toSegment start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0.000_001 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        var t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        t = min(1, max(0, t))
        let px = start.x + t * dx
        let py = start.y + t * dy
        return hypot(point.x - px, point.y - py)
    }

    static func intersects(circleCenter: CGPoint,
                           radius: CGFloat,
                           segmentStart: CGPoint,
                           segmentEnd: CGPoint,
                           tolerance: CGFloat = 16) -> Bool {
        distance(from: circleCenter, toSegment: segmentStart, end: segmentEnd)
            <= radius + tolerance
    }

    static func speed(from previous: CGPoint,
                      to current: CGPoint,
                      deltaTime: TimeInterval) -> CGFloat {
        guard deltaTime > 0 else { return 0 }
        return hypot(current.x - previous.x, current.y - previous.y) / CGFloat(deltaTime)
    }
}
