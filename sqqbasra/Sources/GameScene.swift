import SpriteKit

private enum Cat {
    static let player: UInt32 = 1 << 0
    static let ground: UInt32 = 1 << 1
    static let coin: UInt32   = 1 << 2
    static let enemy: UInt32  = 1 << 3
    static let goal: UInt32   = 1 << 4
}

final class Enemy: SKSpriteNode {
    var dir: CGFloat = -1
    var dead = false
}

final class GameScene: SKScene, SKPhysicsContactDelegate {

    private enum Role { case left, right, jump }

    // MARK: Settings (غيّر هذه القيم لتعديل اللعبة)
    private let tile: CGFloat = 32
    private let levelTiles = 124
    private let runSpeed: CGFloat = 230
    private let jumpSpeed: CGFloat = 800
    private let enemySpeed: CGFloat = 55

    private var levelWidth: CGFloat { CGFloat(levelTiles) * tile }

    // MARK: State
    private let player = SKSpriteNode(color: SKColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1),
                                      size: CGSize(width: 26, height: 34))
    private let cam = SKCameraNode()
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let subLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var enemies: [Enemy] = []
    private var touchRoles: [UITouch: Role] = [:]
    private var coinsCollected = 0
    private var totalCoins = 0
    private var isDone = false
    private var canRestart = false
    private var now: TimeInterval = 0
    private var lastGrounded: TimeInterval = -10

    private var leftCenter: CGPoint { CGPoint(x: -size.width / 2 + 90, y: -size.height / 2 + 64) }
    private var rightCenter: CGPoint { CGPoint(x: -size.width / 2 + 190, y: -size.height / 2 + 64) }
    private var jumpCenter: CGPoint { CGPoint(x: size.width / 2 - 90, y: -size.height / 2 + 64) }

    private var moveLeft: Bool { touchRoles.values.contains(.left) }
    private var moveRight: Bool { touchRoles.values.contains(.right) }

    // MARK: Setup
    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = SKColor(red: 0.45, green: 0.75, blue: 0.95, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -18)
        physicsWorld.contactDelegate = self

        buildSky()
        buildLevel()
        buildPlayer()

        camera = cam
        addChild(cam)
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        buildHUD()
    }

    private func buildSky() {
        var x: CGFloat = 100
        while x < levelWidth {
            let c = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 70...120), height: 34))
            c.fillColor = SKColor(white: 1, alpha: 0.85)
            c.strokeColor = .clear
            c.position = CGPoint(x: x, y: CGFloat.random(in: 230...330))
            c.zPosition = -10
            addChild(c)
            x += CGFloat.random(in: 220...380)
        }
    }

    private func solidBody(_ s: CGSize) -> SKPhysicsBody {
        let b = SKPhysicsBody(rectangleOf: s)
        b.isDynamic = false
        b.categoryBitMask = Cat.ground
        b.friction = 0
        b.restitution = 0
        return b
    }

    private func addGround(_ from: Int, _ to: Int) {
        let w = CGFloat(to - from) * tile
        let node = SKSpriteNode(color: SKColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1),
                                size: CGSize(width: w, height: tile * 2))
        node.position = CGPoint(x: CGFloat(from) * tile + w / 2, y: tile)
        node.zPosition = 1
        let grass = SKSpriteNode(color: SKColor(red: 0.3, green: 0.7, blue: 0.25, alpha: 1),
                                 size: CGSize(width: w, height: 8))
        grass.position = CGPoint(x: 0, y: tile - 4)
        grass.zPosition = 1
        node.addChild(grass)
        node.physicsBody = solidBody(node.size)
        addChild(node)
    }

    private func addPlatform(_ col: Int, _ row: Int, _ w: Int) {
        let s = CGSize(width: CGFloat(w) * tile, height: tile)
        let node = SKSpriteNode(color: SKColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1), size: s)
        node.position = CGPoint(x: CGFloat(col) * tile + s.width / 2, y: CGFloat(row) * tile + tile / 2)
        node.zPosition = 1
        let top = SKSpriteNode(color: SKColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1),
                               size: CGSize(width: s.width, height: 6))
        top.position = CGPoint(x: 0, y: tile / 2 - 3)
        top.zPosition = 1
        node.addChild(top)
        node.physicsBody = solidBody(s)
        addChild(node)
    }

    private func addCoin(_ x: CGFloat, _ y: CGFloat) {
        let c = SKNode()
        c.position = CGPoint(x: x, y: y)
        c.zPosition = 2
        let shape = SKShapeNode(circleOfRadius: 9)
        shape.fillColor = .yellow
        shape.strokeColor = .orange
        shape.lineWidth = 2
        shape.run(.repeatForever(.sequence([
            .scaleX(to: 0.3, duration: 0.45),
            .scaleX(to: 1.0, duration: 0.45)
        ])))
        c.addChild(shape)
        let body = SKPhysicsBody(circleOfRadius: 9)
        body.isDynamic = false
        body.categoryBitMask = Cat.coin
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        c.physicsBody = body
        addChild(c)
        totalCoins += 1
    }

    private func addEnemy(_ col: Int) {
        let e = Enemy(texture: nil,
                      color: SKColor(red: 0.45, green: 0.25, blue: 0.1, alpha: 1),
                      size: CGSize(width: 28, height: 26))
        e.position = CGPoint(x: CGFloat(col) * tile + tile / 2, y: tile * 2 + 16)
        e.zPosition = 3
        for dx: CGFloat in [-6, 6] {
            let eye = SKSpriteNode(color: .white, size: CGSize(width: 7, height: 8))
            eye.position = CGPoint(x: dx, y: 3)
            eye.zPosition = 1
            let pupil = SKSpriteNode(color: .black, size: CGSize(width: 3, height: 4))
            pupil.zPosition = 1
            eye.addChild(pupil)
            e.addChild(eye)
        }
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 26, height: 26))
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.categoryBitMask = Cat.enemy
        body.collisionBitMask = Cat.ground
        body.contactTestBitMask = 0
        e.physicsBody = body
        enemies.append(e)
        addChild(e)
    }

    private func addGoal(_ col: Int) {
        let pole = SKSpriteNode(color: .white, size: CGSize(width: 6, height: 160))
        pole.position = CGPoint(x: CGFloat(col) * tile, y: tile * 2 + 80)
        pole.zPosition = 2
        let flag = SKShapeNode(rectOf: CGSize(width: 36, height: 24))
        flag.fillColor = SKColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        flag.strokeColor = .clear
        flag.position = CGPoint(x: 21, y: 66)
        pole.addChild(flag)
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 160))
        body.isDynamic = false
        body.categoryBitMask = Cat.goal
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        pole.physicsBody = body
        addChild(pole)
    }

    private func buildLevel() {
        // الأرض: (من عمود، إلى عمود) والفراغات بينها حفر
        for (a, b) in [(0, 20), (23, 40), (43, 58), (61, 80), (83, 100), (103, 124)] {
            addGround(a, b)
        }

        // المنصات: (عمود، صف، عرض)
        let platforms = [(7, 4, 3), (12, 4, 2), (15, 6, 3), (26, 4, 4), (31, 6, 3),
                         (46, 4, 3), (50, 6, 3), (64, 4, 3), (69, 6, 3), (74, 4, 3),
                         (86, 4, 4), (92, 6, 3), (106, 4, 3), (111, 6, 3)]
        for (c, r, w) in platforms {
            addPlatform(c, r, w)
            for i in 0..<w {
                addCoin(CGFloat(c + i) * tile + tile / 2, CGFloat(r + 1) * tile + 24)
            }
        }

        // عملات فوق الحفر
        for g in [20, 40, 58, 80, 100] {
            let ys: [CGFloat] = [110, 130, 110]
            for i in 0..<3 {
                addCoin(CGFloat(g + i) * tile + tile / 2, ys[i])
            }
        }

        // عملات على الأرض
        for c in [3, 4, 5, 33, 34, 53, 54, 55, 70, 71, 95, 96, 97, 118, 119] {
            addCoin(CGFloat(c) * tile + tile / 2, tile * 2 + 22)
        }

        // الأعداء
        for c in [28, 35, 48, 55, 66, 72, 88, 96, 108, 115] {
            addEnemy(c)
        }

        addGoal(120)

        // جدران جانبية غير مرئية
        for x in [CGFloat(0), levelWidth] {
            let wall = SKNode()
            let b = SKPhysicsBody(edgeFrom: CGPoint(x: x, y: -300), to: CGPoint(x: x, y: 900))
            b.categoryBitMask = Cat.ground
            b.friction = 0
            wall.physicsBody = b
            addChild(wall)
        }
    }

    private func buildPlayer() {
        player.position = CGPoint(x: 80, y: tile * 2 + 19)
        player.zPosition = 5

        let cap = SKSpriteNode(color: SKColor(red: 0.6, green: 0.05, blue: 0.05, alpha: 1),
                               size: CGSize(width: 30, height: 8))
        cap.position = CGPoint(x: 0, y: 15)
        cap.zPosition = 1
        player.addChild(cap)

        let eye = SKSpriteNode(color: .white, size: CGSize(width: 7, height: 9))
        eye.position = CGPoint(x: 6, y: 4)
        eye.zPosition = 1
        let pupil = SKSpriteNode(color: .black, size: CGSize(width: 3, height: 5))
        pupil.position = CGPoint(x: 1, y: 0)
        pupil.zPosition = 1
        eye.addChild(pupil)
        player.addChild(eye)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 34))
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = Cat.player
        body.collisionBitMask = Cat.ground
        body.contactTestBitMask = Cat.coin | Cat.enemy | Cat.goal
        player.physicsBody = body
        addChild(player)
    }

    private func buildHUD() {
        scoreLabel.fontSize = 20
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -size.width / 2 + 50, y: size.height / 2 - 34)
        scoreLabel.zPosition = 100
        cam.addChild(scoreLabel)
        updateScore()

        messageLabel.fontSize = 44
        messageLabel.position = CGPoint(x: 0, y: 10)
        messageLabel.zPosition = 100
        cam.addChild(messageLabel)

        subLabel.fontSize = 20
        subLabel.position = CGPoint(x: 0, y: -30)
        subLabel.zPosition = 100
        cam.addChild(subLabel)

        makeButton("←", at: leftCenter)
        makeButton("→", at: rightCenter)
        makeButton("↑", at: jumpCenter)
    }

    private func makeButton(_ symbol: String, at p: CGPoint) {
        let b = SKShapeNode(circleOfRadius: 38)
        b.fillColor = SKColor(white: 1, alpha: 0.28)
        b.strokeColor = SKColor(white: 1, alpha: 0.6)
        b.lineWidth = 2
        b.position = p
        b.zPosition = 100
        let l = SKLabelNode(text: symbol)
        l.fontName = "AvenirNext-Bold"
        l.fontSize = 30
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        b.addChild(l)
        cam.addChild(b)
    }

    private func updateScore() {
        scoreLabel.text = "Coins: \(coinsCollected)/\(totalCoins)"
    }

    // MARK: Touch
    private func role(at p: CGPoint) -> Role? {
        if p.x > 0 { return .jump }
        if hypot(p.x - leftCenter.x, p.y - leftCenter.y) < 62 { return .left }
        if hypot(p.x - rightCenter.x, p.y - rightCenter.y) < 62 { return .right }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDone {
            if canRestart {
                canRestart = false
                restart()
            }
            return
        }
        for t in touches {
            if let r = role(at: t.location(in: cam)) {
                touchRoles[t] = r
                if r == .jump { jump() }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDone { return }
        for t in touches {
            let r = role(at: t.location(in: cam))
            let old = touchRoles[t]
            if r != old {
                if old == .jump { cutJump() }
                touchRoles[t] = r
                if r == .jump { jump() }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    private func release(_ touches: Set<UITouch>) {
        for t in touches {
            if touchRoles[t] == .jump { cutJump() }
            touchRoles[t] = nil
        }
    }

    private func jump() {
        guard !isDone, now - lastGrounded < 0.12 else { return }
        lastGrounded = -10
        player.physicsBody?.velocity.dy = jumpSpeed
    }

    private func cutJump() {
        if let v = player.physicsBody?.velocity.dy, v > 300 {
            player.physicsBody?.velocity.dy = v * 0.5
        }
    }

    // MARK: Loop
    override func update(_ currentTime: TimeInterval) {
        now = currentTime
        guard !isDone else { return }

        if isGrounded(), (player.physicsBody?.velocity.dy ?? 0) <= 50 {
            lastGrounded = currentTime
        }

        var dir: CGFloat = 0
        if moveLeft { dir -= 1 }
        if moveRight { dir += 1 }
        player.physicsBody?.velocity.dx = dir * runSpeed
        if dir != 0 { player.xScale = dir > 0 ? 1 : -1 }

        for e in enemies where !e.dead && e.parent != nil {
            patrol(e)
        }

        if player.position.y < -80 { die() }
    }

    override func didSimulatePhysics() {
        let halfW = size.width / 2
        let x = min(max(player.position.x, halfW), levelWidth - halfW)
        cam.position = CGPoint(x: x, y: size.height / 2)
    }

    private func rayHitsGround(from s: CGPoint, to e: CGPoint) -> Bool {
        var hit = false
        physicsWorld.enumerateBodies(alongRayStart: s, end: e) { body, _, _, stop in
            if body.categoryBitMask == Cat.ground {
                hit = true
                stop.pointee = true
            }
        }
        return hit
    }

    private func isGrounded() -> Bool {
        let y0 = player.position.y - player.size.height / 2
        let off = player.size.width / 2 - 4
        for dx in [-off, off] {
            let x = player.position.x + dx
            if rayHitsGround(from: CGPoint(x: x, y: y0 - 1), to: CGPoint(x: x, y: y0 - 5)) {
                return true
            }
        }
        return false
    }

    private func patrol(_ e: Enemy) {
        let ahead = e.position.x + e.dir * 18
        let footY = e.position.y - e.size.height / 2
        let wall = rayHitsGround(from: CGPoint(x: e.position.x, y: e.position.y),
                                 to: CGPoint(x: ahead, y: e.position.y))
        let floor = rayHitsGround(from: CGPoint(x: ahead, y: footY + 2),
                                  to: CGPoint(x: ahead, y: footY - 6))
        if wall || !floor { e.dir = -e.dir }
        e.physicsBody?.velocity.dx = e.dir * enemySpeed
    }

    // MARK: Contacts
    func didBegin(_ contact: SKPhysicsContact) {
        guard !isDone else { return }
        let a = contact.bodyA
        let b = contact.bodyB
        let other = (a.categoryBitMask == Cat.player) ? b : a
        guard other.categoryBitMask != Cat.player, let node = other.node else { return }

        switch other.categoryBitMask {
        case Cat.coin:
            node.removeFromParent()
            coinsCollected += 1
            updateScore()
        case Cat.enemy:
            if let e = node as? Enemy { hit(e) }
        case Cat.goal:
            win()
        default:
            break
        }
    }

    private func hit(_ e: Enemy) {
        guard !e.dead else { return }
        let feet = player.position.y - player.size.height / 2
        if feet > e.position.y - 2 {
            e.dead = true
            e.physicsBody?.categoryBitMask = 0
            e.physicsBody?.collisionBitMask = 0
            e.physicsBody?.velocity = .zero
            e.physicsBody?.isDynamic = false
            e.run(.sequence([.scaleY(to: 0.2, duration: 0.08),
                             .wait(forDuration: 0.25),
                             .removeFromParent()]))
            player.physicsBody?.velocity.dy = 520
        } else {
            die()
        }
    }

    private func die() {
        guard !isDone else { return }
        isDone = true
        touchRoles.removeAll()
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.velocity = CGVector(dx: 0, dy: 520)
        messageLabel.text = "Oops!"
        run(.sequence([.wait(forDuration: 1.0),
                       .run { [weak self] in self?.restart() }]))
    }

    private func win() {
        guard !isDone else { return }
        isDone = true
        touchRoles.removeAll()
        player.physicsBody?.velocity = .zero
        messageLabel.text = "YOU WIN!"
        subLabel.text = "Coins: \(coinsCollected)/\(totalCoins)"
        run(.sequence([.wait(forDuration: 1.0),
                       .run { [weak self] in
                           self?.subLabel.text = "Tap to play again"
                           self?.canRestart = true
                       }]))
    }

    private func restart() {
        let s = GameScene(size: size)
        s.scaleMode = scaleMode
        view?.presentScene(s, transition: .fade(withDuration: 0.4))
    }
}
