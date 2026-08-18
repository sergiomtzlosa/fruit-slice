import SpriteKit

/// Tapered, glowing blade trail. Points are filtered/predicted by the input layer,
/// then rendered as an interpolated ribbon for a smooth high-refresh feel.
final class BladeTrailNode: SKNode {
    private struct TimedPoint {
        var point: CGPoint
        var time: TimeInterval
    }

    private let glowShape = SKShapeNode()
    private let coreShape = SKShapeNode()
    private let sparkEmitter = SKEmitterNode()
    private var points: [TimedPoint] = []
    private let maxAge: TimeInterval = 0.18
    private let maxPoints = 18
    private let maximumWidth: CGFloat = 15

    override init() {
        super.init()
        zPosition = 500
        glowShape.strokeColor = .clear
        glowShape.fillColor = NSColor(calibratedRed: 0.35, green: 1.0, blue: 0.88, alpha: 0.38)
        glowShape.lineWidth = 0
        glowShape.glowWidth = 0
        glowShape.blendMode = .add
        glowShape.isAntialiased = true
        glowShape.zPosition = 0
        addChild(glowShape)

        coreShape.strokeColor = .clear
        coreShape.fillColor = NSColor(calibratedWhite: 1.0, alpha: 0.95)
        coreShape.lineWidth = 0
        coreShape.isAntialiased = true
        coreShape.zPosition = 1
        addChild(coreShape)

        sparkEmitter.particleTexture = Art.texture(named: "spark")
        sparkEmitter.particleBirthRate = 0
        sparkEmitter.numParticlesToEmit = 0
        sparkEmitter.particleLifetime = 0.38
        sparkEmitter.particleLifetimeRange = 0.18
        sparkEmitter.particleSpeed = 55
        sparkEmitter.particleSpeedRange = 35
        sparkEmitter.emissionAngleRange = .pi * 2
        sparkEmitter.particleAlpha = 0.8
        sparkEmitter.particleAlphaSpeed = -2.2
        sparkEmitter.particleScale = 0.16
        sparkEmitter.particleScaleRange = 0.1
        sparkEmitter.particleScaleSpeed = -0.25
        sparkEmitter.particleColor = NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.92, alpha: 1)
        sparkEmitter.particleColorBlendFactor = 1
        sparkEmitter.particleBlendMode = .add
        sparkEmitter.zPosition = 2
        addChild(sparkEmitter)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPoint(_ point: CGPoint, timestamp: TimeInterval) {
        if let last = points.last {
            let distance = hypot(point.x - last.point.x, point.y - last.point.y)
            if distance < 0.6 && timestamp - last.time < 0.025 {
                return
            }
        }
        points.append(TimedPoint(point: point, time: timestamp))
        if points.count > maxPoints {
            points.removeFirst(points.count - maxPoints)
        }
        sparkEmitter.position = point
        sparkEmitter.particleBirthRate = 90
        rebuildPath()
    }

    func agePoints(now: TimeInterval) {
        let cutoff = now - maxAge
        if let firstValid = points.firstIndex(where: { $0.time >= cutoff }) {
            if firstValid > 0 {
                points.removeFirst(firstValid)
            }
        } else {
            points.removeAll()
        }
        if points.count < 2 {
            sparkEmitter.particleBirthRate = 0
        }
        rebuildPath()
    }

    func fadeOut(now: TimeInterval) {
        agePoints(now: now)
        if let last = points.last {
            sparkEmitter.position = last.point
        }
        sparkEmitter.particleBirthRate = 0
    }

    func clear() {
        points.removeAll()
        sparkEmitter.particleBirthRate = 0
        glowShape.path = nil
        coreShape.path = nil
    }

    private func rebuildPath() {
        guard points.count >= 2 else {
            glowShape.path = nil
            coreShape.path = nil
            return
        }
        let smoothed = Self.catmullRom(points.map(\.point), samplesPerSegment: 4)
        guard smoothed.count >= 2 else { return }
        let total = CGFloat(max(1, smoothed.count - 1))
        var leftGlow: [CGPoint] = []
        var rightGlow: [CGPoint] = []
        var leftCore: [CGPoint] = []
        var rightCore: [CGPoint] = []

        for i in 0..<smoothed.count {
            let p = smoothed[i]
            let prev = smoothed[max(0, i - 1)]
            let next = smoothed[min(smoothed.count - 1, i + 1)]
            var tx = next.x - prev.x
            var ty = next.y - prev.y
            let len = hypot(tx, ty)
            if len < 0.001 {
                tx = 1
                ty = 0
            } else {
                tx /= len
                ty /= len
            }
            let nx = -ty
            let ny = tx
            let u = CGFloat(i) / total
            // Keep a wide slash near the fingertip and a tapered, wispy tail.
            let width = 1.2 + maximumWidth * pow(u, 0.65)
            let glowWidth = width * 2.2
            let coreWidth = width * 0.72
            leftGlow.append(CGPoint(x: p.x + nx * glowWidth, y: p.y + ny * glowWidth))
            rightGlow.append(CGPoint(x: p.x - nx * glowWidth, y: p.y - ny * glowWidth))
            leftCore.append(CGPoint(x: p.x + nx * coreWidth, y: p.y + ny * coreWidth))
            rightCore.append(CGPoint(x: p.x - nx * coreWidth, y: p.y - ny * coreWidth))
        }

        glowShape.path = Self.polygon(leftGlow + rightGlow.reversed())
        coreShape.path = Self.polygon(leftCore + rightCore.reversed())
        glowShape.alpha = 0.9
        coreShape.alpha = 1.0
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    private static func catmullRom(_ points: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var result: [CGPoint] = []
        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]
            for s in 0..<samplesPerSegment {
                let t = CGFloat(s) / CGFloat(samplesPerSegment)
                let t2 = t * t
                let t3 = t2 * t
                let x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t +
                    (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                    (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
                let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t +
                    (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                    (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
                result.append(CGPoint(x: x, y: y))
            }
        }
        if let last = points.last { result.append(last) }
        return result
    }
}
