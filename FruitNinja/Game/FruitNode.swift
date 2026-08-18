import SpriteKit

final class FruitNode: SKNode {
    let kind: FruitKind?
    let isBomb: Bool
    let hitRadius: CGFloat
    let displaySize: CGFloat
    var velocity: CGVector = .zero
    var spin: CGFloat = 0
    var hasEnteredScreen = false
    var isSliced = false
    private(set) var sprite: SKSpriteNode!

    init(kind: FruitKind, size: CGFloat) {
        self.kind = kind
        self.isBomb = false
        self.displaySize = size
        self.hitRadius = size * 0.36
        super.init()
        let texture = Art.texture(named: kind.textureName)
            ?? Art.fallbackTexture(color: kind.juiceColor)
        configureSprite(texture: texture, size: size, glowColor: kind.juiceColor)
        name = "fruit"
    }

    init(bombWithSize size: CGFloat) {
        self.kind = nil
        self.isBomb = true
        self.displaySize = size
        self.hitRadius = size * 0.36
        super.init()
        let texture = Art.texture(named: "bomb")
            ?? Art.fallbackTexture(color: .darkGray)
        configureSprite(texture: texture, size: size,
                        glowColor: NSColor(calibratedRed: 1, green: 0.48, blue: 0.18, alpha: 1))
        name = "bomb"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSprite(texture: SKTexture, size: CGFloat, glowColor: NSColor) {
        // A soft colored backlight keeps fruit readable over a bright camera feed.
        if let spark = Art.texture(named: "spark") {
            let glow = SKSpriteNode(texture: spark,
                                    size: CGSize(width: size * 1.55, height: size * 1.55))
            glow.color = glowColor
            glow.colorBlendFactor = 1
            glow.alpha = 0.22
            glow.blendMode = .add
            glow.zPosition = -1
            addChild(glow)
        }
        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: size, height: size))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.zPosition = 0
        addChild(sprite)
        self.sprite = sprite
    }

    func update(deltaTime: TimeInterval, gravity: CGFloat) {
        let dt = CGFloat(deltaTime)
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        velocity.dy -= gravity * dt
        zRotation += spin * dt
        if !hasEnteredScreen && position.y > hitRadius {
            hasEnteredScreen = true
        }
    }
}
