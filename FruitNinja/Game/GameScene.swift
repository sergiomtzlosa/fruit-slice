import AppKit
import SpriteKit

struct BladeInputSample {
    let point: CGPoint
    let timestamp: TimeInterval
    let present: Bool
}

final class GameScene: SKScene {
    private enum Phase {
        case waiting
        case countdown
        case playing
        case paused
        case handLost
        case ended
    }

    // MARK: Public hooks

    var bladeProvider: (() -> BladeInputSample?)?
    var onCountdownTick: ((Int) -> Void)?
    var onGameStart: (() -> Void)?
    var onSlice: ((FruitKind, Int) -> Void)?
    var onBomb: (() -> Void)?
    var onLifeLost: (() -> Void)?
    var onExtraLife: (() -> Void)?
    var onGameOver: ((GameSummary) -> Void)?

    let difficulty: Difficulty
    private(set) var mouseMode: Bool
    private(set) var session: GameSession

    var isUserPaused: Bool { phase == .paused }
    var hasEnded: Bool { phase == .ended }
    var trackingDebugInfo: String = "" {
        didSet { updateDebugLabel() }
    }

#if DEBUG
    var debugFruitPositions: [CGPoint] {
        fruitNodes.filter { !$0.isBomb }.map(\.position)
    }

    func debugEndGame() {
        guard phase != .ended else { return }
        finishGame()
    }
#endif

    // MARK: Scene nodes

    private let worldNode = SKNode()
    private let hudNode = SKNode()
    private let trail = BladeTrailNode()
    private var topShade: SKSpriteNode!
    private var bottomShade: SKSpriteNode!
    private var scoreCaption: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var livesCaption: SKLabelNode!
    private var livesLabel: SKLabelNode!
    private var difficultyLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var subMessageLabel: SKLabelNode!
    private var debugLabel: SKLabelNode!
    private var pausePanel: SKShapeNode!
    private var pauseTitle: SKLabelNode!
    private var pauseSubtitle: SKLabelNode!

    // MARK: Runtime state

    private var phase: Phase = .waiting
    private var phaseBeforePause: Phase = .playing
    private var lastUpdateTime: TimeInterval = 0
    private var waitAccumulator: TimeInterval = 0
    private var countdownRemaining: TimeInterval = 0
    private var currentCountdownNumber = 3
    private var missingHandTime: TimeInterval = 0
    private var handRecoveryTime: TimeInterval = 0
    private var lastHandPresentTime: TimeInterval = 0
    private var nextSpawnTime: TimeInterval = 0
    private var pendingSpawns: [(time: TimeInterval, isBomb: Bool)] = []
    private var fruitNodes: [FruitNode] = []
    private var halves: [(node: SKSpriteNode, velocity: CGVector, spin: CGFloat, age: TimeInterval)] = []
    private var lastBladePoint: CGPoint?
    private var lastBladeFrameTime: TimeInterval = 0
    private var comboCount = 0
    private var lastComboTime: TimeInterval = 0
    private var didReportGameOver = false
    private var lastFlashTime: TimeInterval = 0
    private let baseGravity: CGFloat = 1600

    init(size: CGSize, difficulty: Difficulty, mouseMode: Bool) {
        self.difficulty = difficulty
        self.mouseMode = mouseMode
        self.session = GameSession(difficulty: difficulty)
        super.init(size: size)
        self.anchorPoint = .zero
        self.scaleMode = .resizeFill
        self.backgroundColor = .clear
        worldNode.zPosition = 10
        addChild(worldNode)
        addChild(trail)
        hudNode.zPosition = 1000
        addChild(hudNode)
        buildHUD()
        layoutHUD()
        phase = .waiting
        updateWaitingMessage()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        if size.width < 10 || size.height < 10 {
            size = view.bounds.size
            layoutHUD()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    // MARK: Setup

    private func buildHUD() {
        topShade = SKSpriteNode(color: NSColor(calibratedWhite: 0, alpha: 0.28),
                                size: CGSize(width: size.width, height: 130))
        topShade.anchorPoint = CGPoint(x: 0, y: 0)
        topShade.zPosition = 890
        hudNode.addChild(topShade)

        bottomShade = SKSpriteNode(color: NSColor(calibratedWhite: 0, alpha: 0.14),
                                   size: CGSize(width: size.width, height: 80))
        bottomShade.anchorPoint = CGPoint(x: 0, y: 0)
        bottomShade.zPosition = 890
        hudNode.addChild(bottomShade)

        scoreCaption = makeLabel(text: "SCORE", fontSize: 15,
                                 color: NSColor(calibratedWhite: 1, alpha: 0.62),
                                 font: "AvenirNext-DemiBold")
        scoreCaption.horizontalAlignmentMode = .left
        hudNode.addChild(scoreCaption)

        scoreLabel = makeLabel(text: "0", fontSize: 38, color: .white, font: "AvenirNext-Bold")
        scoreLabel.horizontalAlignmentMode = .left
        hudNode.addChild(scoreLabel)

        livesCaption = makeLabel(text: "LIVES", fontSize: 15,
                                 color: NSColor(calibratedWhite: 1, alpha: 0.62),
                                 font: "AvenirNext-DemiBold")
        livesCaption.horizontalAlignmentMode = .right
        hudNode.addChild(livesCaption)

        livesLabel = makeLabel(text: heartString(3), fontSize: 30,
                               color: NSColor(calibratedRed: 1, green: 0.37, blue: 0.5, alpha: 1),
                               font: "AvenirNext-Bold")
        livesLabel.horizontalAlignmentMode = .right
        hudNode.addChild(livesLabel)

        difficultyLabel = makeLabel(text: difficulty.displayName.uppercased(),
                                    fontSize: 15,
                                    color: NSColor(calibratedRed: 0.6, green: 1, blue: 0.88, alpha: 0.9),
                                    font: "AvenirNext-DemiBold")
        hudNode.addChild(difficultyLabel)

        comboLabel = makeLabel(text: "", fontSize: 27,
                               color: NSColor(calibratedRed: 1, green: 0.84, blue: 0.35, alpha: 1),
                               font: "AvenirNext-Bold")
        comboLabel.alpha = 0
        hudNode.addChild(comboLabel)

        messageLabel = makeLabel(text: "", fontSize: 42, color: .white, font: "AvenirNextCondensed-Heavy")
        messageLabel.zPosition = 1100
        hudNode.addChild(messageLabel)

        subMessageLabel = makeLabel(text: "", fontSize: 19,
                                    color: NSColor(calibratedWhite: 1, alpha: 0.78),
                                    font: "AvenirNext-Medium")
        subMessageLabel.zPosition = 1100
        hudNode.addChild(subMessageLabel)

        debugLabel = makeLabel(text: "", fontSize: 12,
                               color: NSColor(calibratedRed: 0.55, green: 1, blue: 0.9, alpha: 0.9),
                               font: "Menlo")
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.alpha = 0
        hudNode.addChild(debugLabel)

        let panelSize = CGSize(width: 480, height: 188)
        pausePanel = SKShapeNode(rectOf: panelSize, cornerRadius: 26)
        pausePanel.fillColor = NSColor(calibratedRed: 0.03, green: 0.1, blue: 0.14, alpha: 0.88)
        pausePanel.strokeColor = NSColor(calibratedRed: 0.5, green: 1, blue: 0.86, alpha: 0.5)
        pausePanel.lineWidth = 1.5
        pausePanel.zPosition = 1200
        pausePanel.isHidden = true
        hudNode.addChild(pausePanel)

        pauseTitle = makeLabel(text: "PAUSED", fontSize: 40, color: .white, font: "AvenirNextCondensed-Heavy")
        pauseTitle.position = CGPoint(x: 0, y: 22)
        pauseTitle.zPosition = 1201
        pausePanel.addChild(pauseTitle)
        pauseSubtitle = makeLabel(text: "Esc to resume  •  M for menu", fontSize: 16,
                                  color: NSColor(calibratedWhite: 1, alpha: 0.7),
                                  font: "AvenirNext-Medium")
        pauseSubtitle.position = CGPoint(x: 0, y: -30)
        pauseSubtitle.zPosition = 1201
        pausePanel.addChild(pauseSubtitle)
    }

    private func layoutHUD() {
        guard topShade != nil else { return }
        let w = size.width
        let h = size.height
        topShade.size = CGSize(width: w, height: 132)
        topShade.position = CGPoint(x: 0, y: h - 132)
        bottomShade.size = CGSize(width: w, height: 80)
        bottomShade.position = CGPoint(x: 0, y: 0)
        scoreCaption.position = CGPoint(x: 36, y: h - 56)
        scoreLabel.position = CGPoint(x: 36, y: h - 92)
        livesCaption.position = CGPoint(x: w - 36, y: h - 56)
        livesLabel.position = CGPoint(x: w - 36, y: h - 92)
        difficultyLabel.position = CGPoint(x: w / 2, y: h - 46)
        comboLabel.position = CGPoint(x: w / 2, y: h * 0.74)
        messageLabel.position = CGPoint(x: w / 2, y: h * 0.58)
        subMessageLabel.position = CGPoint(x: w / 2, y: h * 0.58 - 52)
        debugLabel.position = CGPoint(x: 28, y: 24)
        pausePanel.position = CGPoint(x: w / 2, y: h / 2)
    }

    private func makeLabel(text: String, fontSize: CGFloat, color: NSColor,
                           font: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1000
        return label
    }

    private func heartString(_ lives: Int) -> String {
        Array(repeating: "♥", count: max(0, lives)).joined(separator: " ")
    }

    // MARK: Public actions

    func pauseGame() {
        guard phase == .playing || phase == .handLost || phase == .countdown else { return }
        phaseBeforePause = phase
        phase = .paused
        pausePanel.isHidden = false
        trail.fadeOut(now: CACurrentMediaTime())
        lastBladePoint = nil
        lastBladeFrameTime = 0
    }

    func resumeGame() {
        guard phase == .paused else { return }
        phase = phaseBeforePause
        pausePanel.isHidden = true
        let now = CACurrentMediaTime()
        lastUpdateTime = now
        nextSpawnTime = max(nextSpawnTime, now + 0.5)
        lastBladePoint = nil
        lastBladeFrameTime = 0
        if phase == .handLost {
            missingHandTime = 0.7
        }
    }

    func setMouseMode(_ enabled: Bool) {
        mouseMode = enabled
        if phase == .waiting {
            updateWaitingMessage()
        }
    }

    func toggleDebug() {
        debugLabel.alpha = debugLabel.alpha > 0.5 ? 0 : 1
        updateDebugLabel()
    }

    private func updateDebugLabel() {
        guard let debugLabel else { return }
        if mouseMode {
            debugLabel.text = "MOUSE BLADE • 60 fps target\n" + trackingDebugInfo
        } else {
            debugLabel.text = "VISION HAND • GPU/ANE\n" + trackingDebugInfo
        }
    }

    // MARK: Scene update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let dt = min(max(currentTime - lastUpdateTime, 0), 0.05)
        lastUpdateTime = currentTime

        if phase == .paused || phase == .ended {
            trail.fadeOut(now: currentTime)
            return
        }

        let sample = bladeProvider?()
        // Capture the previous blade position before this frame's sample is
        // stored. Slice detection needs the segment travelled since last frame.
        let previousBladePoint = lastBladePoint
        let previousBladeTime = lastBladeFrameTime
        updateBlade(sample, now: currentTime)
        if let sample, sample.present {
            lastBladePoint = sample.point
            lastBladeFrameTime = currentTime
        } else {
            lastBladePoint = nil
            lastBladeFrameTime = 0
        }

        switch phase {
        case .waiting:
            updateWaiting(dt: dt, sample: sample)
        case .countdown:
            updateCountdown(dt: dt, now: currentTime, sample: sample)
        case .playing:
            updatePlaying(dt: dt, now: currentTime, sample: sample,
                          previousBladePoint: previousBladePoint,
                          previousBladeTime: previousBladeTime)
        case .handLost:
            updateHandLost(dt: dt, sample: sample, now: currentTime)
        case .paused, .ended:
            break
        }
    }

    private func updateWaiting(dt: TimeInterval, sample: BladeInputSample?) {
        if mouseMode {
            waitAccumulator += dt
        } else if sample?.present == true {
            waitAccumulator += dt
        } else {
            waitAccumulator = max(0, waitAccumulator - dt * 2)
        }
        if waitAccumulator >= (mouseMode ? 0.6 : 0.45) {
            beginCountdown()
        }
    }

    private func beginCountdown() {
        phase = .countdown
        countdownRemaining = 3.0
        currentCountdownNumber = 3
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = "3"
        subMessageLabel.text = "Get ready"
        onCountdownTick?(3)
    }

    private func updateCountdown(dt: TimeInterval, now: TimeInterval,
                                 sample: BladeInputSample?) {
        countdownRemaining -= dt
        let number = max(1, Int(ceil(countdownRemaining)))
        if number != currentCountdownNumber {
            currentCountdownNumber = number
            messageLabel.text = "\(number)"
            pulse(messageLabel)
            onCountdownTick?(number)
        }
        if countdownRemaining <= 0 {
            phase = .playing
            messageLabel.text = "SLICE!"
            subMessageLabel.text = ""
            messageLabel.run(.sequence([.wait(forDuration: 0.5),
                                        .fadeOut(withDuration: 0.2)]))
            nextSpawnTime = now + 0.3
            lastUpdateTime = now
            onGameStart?()
            if !mouseMode && sample?.present != true {
                lastHandPresentTime = now - 1
            }
        }
    }

    private func updatePlaying(dt: TimeInterval, now: TimeInterval,
                               sample: BladeInputSample?,
                               previousBladePoint: CGPoint?,
                               previousBladeTime: TimeInterval) {
        if !mouseMode && sample?.present != true {
            missingHandTime += dt
            if missingHandTime > 0.65 {
                enterHandLost()
                return
            }
        } else {
            missingHandTime = 0
        }

        updateSpawner(now: now)
        updateFruits(dt: dt, now: now)
        updateHalves(dt: dt)
        trail.agePoints(now: now)

        if let sample, sample.present, let previous = previousBladePoint {
            let delta = now - previousBladeTime
            let speed = SliceDetector.speed(from: previous, to: sample.point, deltaTime: delta)
            if delta > 0.0008 && speed >= SliceDetector.minimumSliceSpeed {
                detectSlices(from: previous, to: sample.point, now: now)
            }
        }
    }

    private func updateBlade(_ sample: BladeInputSample?, now: TimeInterval) {
        guard let sample, sample.present else {
            trail.fadeOut(now: now)
            return
        }
        trail.addPoint(sample.point, timestamp: now)
        trail.agePoints(now: now)
    }

    private func enterHandLost() {
        phase = .handLost
        handRecoveryTime = 0
        pendingSpawns.removeAll()
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = "HAND LOST"
        subMessageLabel.text = "Show your hand to keep slicing"
        trail.clear()
        lastBladePoint = nil
        lastBladeFrameTime = 0
    }

    private func updateHandLost(dt: TimeInterval, sample: BladeInputSample?,
                                now: TimeInterval) {
        updateHalves(dt: dt)
        if sample?.present == true {
            handRecoveryTime += dt
            if handRecoveryTime > 0.2 {
                phase = .playing
                missingHandTime = 0
                nextSpawnTime = now + 0.6
                messageLabel.removeAllActions()
                messageLabel.run(.sequence([.wait(forDuration: 0.35),
                                            .fadeOut(withDuration: 0.2)]))
                subMessageLabel.text = ""
                lastUpdateTime = now
            }
        } else {
            handRecoveryTime = 0
        }
    }

    private func updateSpawner(now: TimeInterval) {
        while let first = pendingSpawns.first,
              first.time <= now,
              fruitNodes.count < difficulty.maxOnscreenFruits {
            pendingSpawns.removeFirst()
            spawnFruit(isBomb: first.isBomb)
        }
        if pendingSpawns.isEmpty &&
            now >= nextSpawnTime &&
            fruitNodes.count < difficulty.maxOnscreenFruits {
            queueWave(at: now)
            nextSpawnTime = now + difficulty.randomSpawnInterval()
        } else if now >= nextSpawnTime {
            nextSpawnTime = now + 0.2
        }
    }

    private func queueWave(at now: TimeInterval) {
        let count = difficulty.randomFruitCount()
        for i in 0..<count {
            let isBomb = Double.random(in: 0..<1) < difficulty.bombChance
            pendingSpawns.append((time: now + Double(i) * 0.16, isBomb: isBomb))
        }
    }

    private func spawnFruit(isBomb: Bool) {
        guard fruitNodes.count < difficulty.maxOnscreenFruits else { return }
        let width = max(size.width, 640)
        let height = max(size.height, 480)
        let scale = difficulty.speedScale
        let gravity = baseGravity * scale * scale
        let startX = CGFloat.random(in: width * 0.08...width * 0.92)
        let startY = -CGFloat(90)
        let targetHeight = height * CGFloat.random(in: 0.55...0.86)
        let rise = max(220, targetHeight - startY)
        let vy = sqrt(2 * gravity * rise)
        let flightTime = max(0.5, (2 * vy) / gravity)
        let targetX = CGFloat.random(in: width * 0.18...width * 0.82)
        let vx = (targetX - startX) / flightTime

        let node: FruitNode
        if isBomb {
            node = FruitNode(bombWithSize: 102)
        } else {
            let kind = FruitKind.allCases.randomElement() ?? .watermelon
            node = FruitNode(kind: kind, size: kind.displaySize)
        }
        node.position = CGPoint(x: startX, y: startY)
        node.velocity = CGVector(dx: vx, dy: vy)
        node.spin = CGFloat.random(in: -2.8...2.8)
        node.zPosition = isBomb ? 22 : 20
        node.setScale(CGFloat.random(in: 0.94...1.08))
        worldNode.addChild(node)
        fruitNodes.append(node)
    }

    private func updateFruits(dt: TimeInterval, now: TimeInterval) {
        let gravity = baseGravity * difficulty.speedScale * difficulty.speedScale
        var missed: [FruitNode] = []
        for node in fruitNodes {
            node.update(deltaTime: dt, gravity: gravity)
            if node.position.y < -140 && node.hasEnteredScreen {
                missed.append(node)
            }
        }
        for node in missed {
            if node.isBomb {
                removeFruitNode(node)
            } else {
                handleMiss(node)
            }
            if phase == .ended { break }
        }
    }

    private func updateHalves(dt: TimeInterval) {
        var expired: [SKSpriteNode] = []
        for index in halves.indices {
            var item = halves[index]
            item.age += dt
            item.velocity.dy -= baseGravity * 0.75 * CGFloat(dt)
            item.node.position.x += item.velocity.dx * CGFloat(dt)
            item.node.position.y += item.velocity.dy * CGFloat(dt)
            item.node.zRotation += item.spin * CGFloat(dt)
            if item.age > 1.4 {
                item.node.alpha = max(0, CGFloat(1.4 - item.age) / 0.35)
            }
            halves[index] = item
            if item.age > 1.8 || item.node.position.y < -200 {
                expired.append(item.node)
            }
        }
        if !expired.isEmpty {
            for node in expired { node.removeFromParent() }
            halves.removeAll { $0.age > 1.8 || $0.node.position.y < -200 }
        }
    }

    // MARK: Slice detection and scoring

    private func detectSlices(from start: CGPoint, to end: CGPoint, now: TimeInterval) {
        let bladeAngle = atan2(end.y - start.y, end.x - start.x)
        let candidates = fruitNodes
        for node in candidates {
            guard node.parent != nil, !node.isSliced else { continue }
            guard SliceDetector.intersects(circleCenter: node.position,
                                           radius: node.hitRadius,
                                           segmentStart: start,
                                           segmentEnd: end) else { continue }
            if node.isBomb {
                sliceBomb(node, now: now)
            } else {
                sliceFruit(node, now: now, bladeAngle: bladeAngle)
            }
            if phase == .ended { return }
        }
    }

    private func sliceFruit(_ node: FruitNode, now: TimeInterval, bladeAngle: CGFloat) {
        guard let kind = node.kind else { return }
        node.isSliced = true
        let slicePosition = node.position
        let sliceVelocity = node.velocity
        spawnHalves(kind: kind, at: slicePosition, bladeAngle: bladeAngle,
                    velocity: sliceVelocity, baseScale: node.xScale)
        spawnJuice(kind: kind, at: slicePosition)
        spawnSliceFlash(at: slicePosition, angle: bladeAngle, color: kind.juiceColor)
        removeFruitNode(node)

        if now - lastComboTime <= 0.6 {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastComboTime = now
        session.noteCombo(comboCount)

        let bonus = max(0, comboCount - 1) * 5
        let points = 10 + bonus
        let awarded = session.recordSlice(points: points)
        updateHUD()
        showFloatingText("+\(points)", at: slicePosition,
                         color: NSColor(calibratedRed: 1, green: 0.9, blue: 0.55, alpha: 1))
        if comboCount >= 2 {
            showCombo(comboCount)
        }
        onSlice?(kind, comboCount)
        for _ in 0..<awarded {
            showAnnouncement("EXTRA LIFE", color: NSColor(calibratedRed: 0.6, green: 1, blue: 0.65, alpha: 1))
            flash(color: NSColor(calibratedRed: 0.25, green: 0.9, blue: 0.55, alpha: 0.2), now: now)
            onExtraLife?()
        }
    }

    private func sliceBomb(_ node: FruitNode, now: TimeInterval) {
        node.isSliced = true
        let position = node.position
        removeFruitNode(node)
        spawnExplosion(at: position)
        flash(color: NSColor(calibratedRed: 1, green: 0.25, blue: 0.2, alpha: 0.3), now: now)
        shakeWorld()
        onBomb?()
        let ended = session.recordBombSlice()
        updateHUD()
        onLifeLost?()
        if ended {
            finishGame()
        }
    }

    private func handleMiss(_ node: FruitNode) {
        removeFruitNode(node)
        let ended = session.recordMiss()
        updateHUD()
        onLifeLost?()
        if let kind = node.kind {
            showFloatingText("MISS", at: CGPoint(x: node.position.x,
                                                 y: max(90, node.position.y + 100)),
                             color: NSColor(calibratedRed: 1, green: 0.4, blue: 0.46, alpha: 1))
            _ = kind
        }
        flash(color: NSColor(calibratedRed: 1, green: 0.1, blue: 0.15, alpha: 0.22),
              now: CACurrentMediaTime())
        if ended {
            finishGame()
        }
    }

    private func removeFruitNode(_ node: FruitNode) {
        node.removeFromParent()
        fruitNodes.removeAll { $0 === node }
    }

    private func updateHUD() {
        scoreLabel.text = "\(session.score)"
        livesLabel.text = heartString(session.lives)
        livesLabel.fontColor = session.lives <= 1
            ? NSColor(calibratedRed: 1, green: 0.25, blue: 0.36, alpha: 1)
            : NSColor(calibratedRed: 1, green: 0.37, blue: 0.5, alpha: 1)
    }

    private func finishGame() {
        guard !didReportGameOver else { return }
        didReportGameOver = true
        phase = .ended
        pendingSpawns.removeAll()
        trail.clear()
        lastBladePoint = nil
        lastBladeFrameTime = 0
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = "GAME OVER"
        subMessageLabel.text = ""
        let summary = session.makeSummary()
        onGameOver?(summary)
    }

    // MARK: Visual effects

    private func spawnHalves(kind: FruitKind, at position: CGPoint, bladeAngle: CGFloat,
                             velocity: CGVector, baseScale: CGFloat) {
        let texture = Art.texture(named: kind.halfTextureName)
            ?? Art.fallbackTexture(color: kind.juiceColor)
        let size = kind.displaySize
        let normal = CGVector(dx: cos(bladeAngle + .pi / 2), dy: sin(bladeAngle + .pi / 2))
        for side in [CGFloat(-1), CGFloat(1)] {
            let sprite = SKSpriteNode(texture: texture,
                                      size: CGSize(width: size, height: size))
            // The half art is a cut-face dome. One half points along the
            // blade normal, the other is rotated so the flat cut edges meet.
            // Nudge them apart immediately so the split reads on the first frame.
            sprite.position = CGPoint(x: position.x + normal.dx * 5 * side,
                                      y: position.y + normal.dy * 5 * side)
            sprite.zRotation = side > 0 ? bladeAngle : bladeAngle + .pi
            sprite.zPosition = 22
            sprite.setScale(baseScale)
            worldNode.addChild(sprite)
            let v = CGVector(
                dx: velocity.dx * 0.30 + normal.dx * 250 * side + CGFloat.random(in: -35...35),
                dy: abs(velocity.dy) * 0.18 + normal.dy * 250 * side + CGFloat.random(in: 90...170)
            )
            halves.append((sprite, v, CGFloat.random(in: -5.5...5.5), 0))
        }
    }

    private func spawnSliceFlash(at position: CGPoint, angle: CGFloat, color: NSColor) {
        let length: CGFloat = 170
        let glow = SKSpriteNode(color: color.withAlphaComponent(0.45),
                                size: CGSize(width: length * 1.1, height: 18))
        glow.position = position
        glow.zRotation = angle
        glow.zPosition = 48
        glow.blendMode = .add
        glow.alpha = 0.9
        worldNode.addChild(glow)
        glow.run(.sequence([
            .group([.fadeOut(withDuration: 0.2), .scaleY(to: 0.12, duration: 0.2)]),
            .removeFromParent()
        ]))

        let core = SKSpriteNode(color: NSColor(calibratedWhite: 1, alpha: 0.95),
                                size: CGSize(width: length, height: 4))
        core.position = position
        core.zRotation = angle
        core.zPosition = 49
        core.blendMode = .add
        worldNode.addChild(core)
        core.run(.sequence([
            .group([.fadeOut(withDuration: 0.16), .scaleY(to: 0.15, duration: 0.16)]),
            .removeFromParent()
        ]))
    }

    private func spawnJuice(kind: FruitKind, at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.texture(named: "spark")
        // A high birth rate turns numParticlesToEmit into a single juicy burst.
        emitter.particleBirthRate = 1_400
        emitter.numParticlesToEmit = 46
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.3
        emitter.particleSpeed = 300
        emitter.particleSpeedRange = 180
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.19
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.25
        emitter.particleColor = kind.juiceColor
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.position = position
        emitter.zPosition = 40
        worldNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.1), .removeFromParent()]))
        emitter.advanceSimulationTime(0.02)
    }

    private func spawnExplosion(at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.texture(named: "spark")
        emitter.particleBirthRate = 2_200
        emitter.numParticlesToEmit = 90
        emitter.particleLifetime = 0.75
        emitter.particleLifetimeRange = 0.35
        emitter.particleSpeed = 470
        emitter.particleSpeedRange = 260
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.32
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.28
        emitter.particleColor = NSColor(calibratedRed: 1, green: 0.58, blue: 0.16, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.position = position
        emitter.zPosition = 60
        worldNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))

        let ring = SKShapeNode(circleOfRadius: 22)
        ring.strokeColor = NSColor(calibratedRed: 1, green: 0.7, blue: 0.25, alpha: 0.9)
        ring.lineWidth = 6
        ring.fillColor = .clear
        ring.position = position
        ring.zPosition = 61
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 5.2, duration: 0.42), .fadeOut(withDuration: 0.42)]),
            .removeFromParent()
        ]))
    }

    private func showFloatingText(_ text: String, at point: CGPoint, color: NSColor) {
        let label = makeLabel(text: text, fontSize: 28, color: color, font: "AvenirNext-Bold")
        label.position = point
        label.zPosition = 600
        label.alpha = 0
        hudNode.addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.06),
            .group([.moveBy(x: 0, y: 56, duration: 0.65),
                    .fadeOut(withDuration: 0.65)]),
            .removeFromParent()
        ]))
    }

    private func showCombo(_ count: Int) {
        comboLabel.removeAllActions()
        comboLabel.text = "COMBO ×\(count)"
        comboLabel.alpha = 1
        comboLabel.setScale(1.2)
        comboLabel.run(.sequence([
            .scale(to: 1.0, duration: 0.12),
            .wait(forDuration: 0.65),
            .fadeOut(withDuration: 0.22)
        ]))
    }

    private func showAnnouncement(_ text: String, color: NSColor) {
        let label = makeLabel(text: text, fontSize: 34, color: color, font: "AvenirNextCondensed-Heavy")
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        label.zPosition = 650
        label.alpha = 0
        hudNode.addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.1),
            .group([.moveBy(x: 0, y: 45, duration: 1.15),
                    .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.6)])]),
            .removeFromParent()
        ]))
    }

    private func flash(color: NSColor, now: TimeInterval) {
        if now - lastFlashTime < 0.08 { return }
        lastFlashTime = now
        let flash = SKSpriteNode(color: color, size: size)
        flash.anchorPoint = .zero
        flash.position = .zero
        flash.zPosition = 800
        flash.alpha = 1
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))
    }

    private func shakeWorld() {
        worldNode.removeAllActions()
        var actions: [SKAction] = []
        for _ in 0..<7 {
            actions.append(.moveBy(x: CGFloat.random(in: -10...10),
                                   y: CGFloat.random(in: -8...8),
                                   duration: 0.035))
        }
        actions.append(.move(to: .zero, duration: 0.05))
        worldNode.run(.sequence(actions))
    }

    private func pulse(_ node: SKNode) {
        node.removeAllActions()
        node.setScale(1.0)
        node.run(.sequence([.scale(to: 1.18, duration: 0.08),
                            .scale(to: 1.0, duration: 0.14)]))
    }

    private func updateWaitingMessage() {
        if mouseMode {
            messageLabel.text = "MOVE YOUR MOUSE TO SLICE"
            messageLabel.fontSize = 38
            subMessageLabel.text = "Mouse Blade mode — slash through fruit, avoid bombs"
        } else {
            messageLabel.text = "RAISE YOUR INDEX FINGER"
            messageLabel.fontSize = 42
            subMessageLabel.text = "Stand back so your hand is in frame. Your finger is the blade."
        }
    }
}
