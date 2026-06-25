import SpriteKit
import SwiftUI

/// SpriteKit projector of the engine. Holds disc nodes keyed by stable id, and plays a
/// DropResolution as an ordered animation timeline — the "unzip" is intra-wave stagger +
/// inter-step sequencing. The scene NEVER decides game logic.
final class WellScene: SKScene {
    var onColumnTap: ((Int) -> Void)?
    var reduceMotion = false

    private let config: GameConfig
    private let world = SKNode()
    private var nodes: [Int: SKNode] = [:]
    private var cell: CGFloat = 100

    init(size: CGSize, config: GameConfig) {
        self.config = config
        super.init(size: size)
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0, y: 0)
        backgroundColor = UIColor(Palette.ink)
        cell = size.width / CGFloat(config.cols)
        addChild(world)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: geometry + nodes

    private func pos(col: Int, row: Int) -> CGPoint {
        CGPoint(x: CGFloat(col) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
    }

    private func discColor(_ value: Int) -> UIColor {
        // warm ordinal scale: 1 = cream … 7 = red (on-brand; high number reads "hot")
        let stops: [(Int, UIColor)] = [(1, UIColor(Palette.paperDeep)), (4, UIColor(Palette.heat1)), (7, UIColor(Palette.heat4))]
        let v = max(1, min(7, value))
        for i in 0..<(stops.count - 1) where v >= stops[i].0 && v <= stops[i + 1].0 {
            let (a, ca) = stops[i], (b, cb) = stops[i + 1]
            let t = CGFloat(v - a) / CGFloat(b - a)
            var ra: CGFloat = 0, ga: CGFloat = 0, ba: CGFloat = 0, aa: CGFloat = 0
            var rb: CGFloat = 0, gb: CGFloat = 0, bb: CGFloat = 0, ab: CGFloat = 0
            ca.getRed(&ra, green: &ga, blue: &ba, alpha: &aa); cb.getRed(&rb, green: &gb, blue: &bb, alpha: &ab)
            return UIColor(red: ra + (rb - ra) * t, green: ga + (gb - ga) * t, blue: ba + (bb - ba) * t, alpha: 1)
        }
        return UIColor(Palette.heat1)
    }

    private func makeNode(id: Int, kind: DiscKind) -> SKNode {
        let r = cell * 0.42
        let shape = SKShapeNode(circleOfRadius: r)
        shape.lineWidth = 0
        let label = SKLabelNode(text: "")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = cell * 0.36
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "label"
        shape.addChild(label)
        shape.name = "disc"
        style(shape, kind)
        return shape
    }

    private func style(_ node: SKNode, _ kind: DiscKind) {
        guard let shape = node as? SKShapeNode, let label = node.childNode(withName: "label") as? SKLabelNode else { return }
        switch kind {
        case .num(let v):
            shape.fillColor = discColor(v)
            label.text = "\(v)"
            label.fontColor = UIColor(Palette.ink)
        case .gray:
            shape.fillColor = UIColor(white: 0.42, alpha: 1)
            label.text = ""
        }
    }

    func setBoard(_ columns: [[Disc]]) {
        world.removeAllChildren()
        nodes.removeAll()
        for c in 0..<columns.count {
            for r in 0..<columns[c].count {
                let d = columns[c][r]
                let n = makeNode(id: d.id, kind: d.kind)
                n.position = pos(col: c, row: r)
                world.addChild(n); nodes[d.id] = n
            }
        }
    }

    // MARK: playback

    func play(_ res: DropResolution, droppedValue: Int, completion: @escaping () -> Void) {
        let node = makeNode(id: res.placedId, kind: .num(droppedValue))
        node.position = pos(col: res.placedCol, row: config.rows)
        world.addChild(node); nodes[res.placedId] = node
        let travel = config.rows - res.placedRow
        let fall = reduceMotion ? 0.05 : min(0.34, 0.12 + 0.03 * Double(travel))
        let drop = SKAction.move(to: pos(col: res.placedCol, row: res.placedRow), duration: fall)
        drop.timingMode = .easeIn
        node.run(drop) { [weak self] in
            self?.playSteps(res.steps, 0, dropCol: res.placedCol, completion: completion)
        }
    }

    private func playSteps(_ steps: [ResolveStep], _ i: Int, dropCol: Int, completion: @escaping () -> Void) {
        guard i < steps.count else { completion(); return }
        let dur = runStep(steps[i], dropCol: dropCol)
        run(.sequence([.wait(forDuration: dur), .run { [weak self] in
            self?.playSteps(steps, i + 1, dropCol: dropCol, completion: completion)
        }]))
    }

    private func runStep(_ step: ResolveStep, dropCol: Int) -> TimeInterval {
        switch step {
        case .wave(let pops, let reveals, let moves, let depth, _):
            Haptics.pop(depth: depth)
            if !reduceMotion && depth >= 4 { shake(depth: depth) }
            if !reduceMotion && depth >= 3 { zoomPunch() }

            for rv in reveals { if let n = nodes[rv.id] { style(n, .num(rv.value)) } }

            let popTime = reduceMotion ? 0.08 : 0.15
            let stagger = reduceMotion ? 0.0 : 0.016
            let sorted = pops.sorted { abs($0.col - dropCol) != abs($1.col - dropCol) ? abs($0.col - dropCol) < abs($1.col - dropCol) : $0.col < $1.col }
            for (idx, p) in sorted.enumerated() {
                guard let n = nodes[p.id] else { continue }
                nodes[p.id] = nil
                let delay = Double(idx) * stagger
                let burstColor = (n as? SKShapeNode)?.fillColor ?? UIColor(Palette.heat3)
                if reduceMotion {
                    n.run(.sequence([.wait(forDuration: delay), .fadeOut(withDuration: 0.1), .removeFromParent()]))
                } else {
                    let anticip = SKAction.scale(to: 1.28, duration: 0.06)
                    let collapse = SKAction.group([.scale(to: 0.1, duration: 0.09), .fadeOut(withDuration: 0.09)])
                    n.run(.sequence([.wait(forDuration: delay), anticip,
                                     .run { [weak self] in self?.burst(at: n.position, color: burstColor) },
                                     collapse, .removeFromParent()]))
                }
            }

            let moveTime = reduceMotion ? 0.08 : 0.20
            for m in moves {
                guard let n = nodes[m.id] else { continue }
                let mv = SKAction.move(to: pos(col: m.col, row: m.toRow), duration: moveTime)
                mv.timingMode = .easeIn
                n.run(.sequence([.wait(forDuration: popTime), mv]))
            }
            return popTime + moveTime + (reduceMotion ? 0.0 : 0.05) + Double(max(0, pops.count - 1)) * stagger

        case .floorRise(let grayIds):
            let up = reduceMotion ? 0.06 : 0.18
            for (_, n) in nodes {
                let mv = SKAction.moveBy(x: 0, y: cell, duration: up); mv.timingMode = .easeOut
                n.run(mv)
            }
            for (c, id) in grayIds.enumerated() {
                let n = makeNode(id: id, kind: .gray)
                n.position = pos(col: c, row: 0)
                n.alpha = 0
                world.addChild(n); nodes[id] = n
                n.run(.fadeIn(withDuration: up))
            }
            return up + 0.04
        }
    }

    private func burst(at p: CGPoint, color: UIColor) {
        let n = reduceMotion ? 0 : Int.random(in: 8...12)
        for _ in 0..<n {
            let spark = SKShapeNode(circleOfRadius: cell * 0.06)
            spark.fillColor = color; spark.lineWidth = 0; spark.position = p
            world.addChild(spark)
            let ang = CGFloat.random(in: 0..<(.pi * 2))
            let dist = CGFloat.random(in: cell * 0.3...cell * 0.7)
            let move = SKAction.move(by: CGVector(dx: cos(ang) * dist, dy: sin(ang) * dist), duration: 0.35)
            move.timingMode = .easeOut
            spark.run(.sequence([.group([move, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func zoomPunch() {
        world.run(.sequence([.scale(to: 1.015, duration: 0.06), .scale(to: 1.0, duration: 0.06)]))
    }

    private func shake(depth: Int) {
        let amp = CGFloat(min(10, 2 + depth))
        var seq: [SKAction] = []
        for _ in 0..<5 {
            seq.append(.moveBy(x: CGFloat.random(in: -amp...amp), y: CGFloat.random(in: -amp...amp), duration: 0.03))
        }
        seq.append(.move(to: .zero, duration: 0.03))
        world.run(.sequence(seq))
    }

    func flashBank() {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = UIColor(Palette.heat1); flash.lineWidth = 0; flash.alpha = 0; flash.zPosition = 50
        addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.25, duration: 0.08), .fadeOut(withDuration: 0.30), .removeFromParent()]))
    }

    // MARK: input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let x = t.location(in: self).x
        let col = max(0, min(config.cols - 1, Int(x / cell)))
        onColumnTap?(col)
    }
}
