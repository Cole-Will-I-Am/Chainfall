import Foundation

// CHAINFALL engine — a pure, deterministic grid sim (no SpriteKit). Drop7's pop+cascade
// fused with RUNG's bank-or-push. The grid is 7 columns, each a bottom-up contiguous
// stack (index 0 = bottom), so gravity is automatic (removing a disc collapses the
// column). The engine emits an ordered step timeline the renderer projects into
// animations; it never returns just a final grid.

enum DiscKind: Equatable { case num(Int); case gray }
struct Disc: Equatable { let id: Int; var kind: DiscKind }

struct GameConfig {
    var cols = 7
    var rows = 9
    var initialRows = 2
    var valueWeights = [2, 3, 4, 4, 4, 3, 2]      // for values 1...7
    // scoring: per popped disc in cascade wave w (1-based) = scoreBase * geo^(w-1)
    var scoreBase = 10
    var geo = 2
    var comboThreshold = 4                         // popsInWave >= this earns a bonus
    var comboBonusPer = 25
    // heat (integer hundredths; 100 = ×1.00)
    var heatStart = 100
    var heatStepPerWave = 25                       // +0.25 per scoring cascade wave
    var heatCap = 600
    var heatResetOnNoPop = true                    // the load-bearing tension lever
    var threatPeriod = 6                           // a gray floor row rises every N drops
}

// --- ordered timeline the renderer plays ---
struct PopEvent: Equatable { let id: Int; let col: Int; let row: Int; let value: Int }
struct MoveEvent: Equatable { let id: Int; let col: Int; let fromRow: Int; let toRow: Int }
struct RevealEvent: Equatable { let id: Int; let col: Int; let row: Int; let value: Int }

enum ResolveStep: Equatable {
    case wave(pops: [PopEvent], reveals: [RevealEvent], moves: [MoveEvent], depth: Int, points: Int)
    case floorRise(grayIds: [Int])                 // a gray inserted at the bottom of each column
}

struct DropResolution: Equatable {
    let placedId: Int
    let placedCol: Int
    let placedRow: Int
    let steps: [ResolveStep]
    let chainDepth: Int                            // number of scoring waves (incl. post-rise)
    let pointsGained: Int
    let heatBefore: Int
    let heatAfter: Int
    let heatReset: Bool
    let busted: Bool
    let unbankedAfter: Int
    let bankedAfter: Int
}

final class ChainfallGame {
    let config: GameConfig
    private var rng: SplitMix64
    private let cum: [Int]
    private let totalWeight: Int

    private(set) var columns: [[Disc]]
    private(set) var nextValue: Int = 1
    private(set) var bankedScore = 0
    private(set) var unbanked = 0
    private(set) var heatH: Int
    private(set) var dropCount = 0
    private(set) var isOver = false
    private var nextId = 0

    var heatMultiplier: Double { Double(heatH) / 100.0 }
    /// What banking right now would lock in.
    var bankable: Int { unbanked * heatH / 100 }
    func columnHeight(_ c: Int) -> Int { columns[c].count }
    var canDrop: Bool { !isOver && columns.contains { $0.count < config.rows } }

    init(seed: UInt64, config: GameConfig = GameConfig()) {
        self.config = config
        self.rng = SplitMix64(seed: seed)
        self.heatH = config.heatStart
        var c = [Int](); var run = 0
        for w in config.valueWeights { run += w; c.append(run) }
        self.cum = c; self.totalWeight = run
        self.columns = Array(repeating: [Disc](), count: config.cols)
        // initial fill: initialRows rows, row-major (row outer, col inner), then settle.
        var v = drawValueRaw()
        for _ in 0..<config.initialRows {
            for col in 0..<config.cols {
                columns[col].append(Disc(id: takeId(), kind: .num(v)))
                v = drawValueRaw()
            }
        }
        // the last drawn value becomes the first nextValue after settling
        var dump: [ResolveStep] = []; var pts = 0; var waves = 0
        resolve(into: &dump, points: &pts, waves: &waves, scoring: false)
        nextValue = v
    }

    private func takeId() -> Int { defer { nextId += 1 }; return nextId }

    private func drawValueRaw() -> Int {
        let r = Int(rng.next() % UInt64(totalWeight))
        var i = 0; while r >= cum[i] { i += 1 }
        return i + 1
    }

    // MARK: drop

    /// Drop the current next disc into column `c`. Returns nil if the move is illegal
    /// (column full or game over).
    func drop(column c: Int) -> DropResolution? {
        guard !isOver, c >= 0, c < config.cols, columns[c].count < config.rows else { return nil }

        let placed = Disc(id: takeId(), kind: .num(nextValue))
        columns[c].append(placed)
        let placedRow = columns[c].count - 1
        dropCount += 1

        var steps: [ResolveStep] = []
        var totalPoints = 0
        var scoringWaves = 0
        resolve(into: &steps, points: &totalPoints, waves: &scoringWaves, scoring: true)

        var busted = false
        if dropCount % config.threatPeriod == 0 {
            if columns.contains(where: { $0.count >= config.rows }) {
                busted = true
                isOver = true
            } else {
                var grayIds: [Int] = []
                for col in 0..<config.cols {
                    let g = Disc(id: takeId(), kind: .gray)
                    columns[col].insert(g, at: 0)
                    grayIds.append(g.id)
                }
                steps.append(.floorRise(grayIds: grayIds))
                resolve(into: &steps, points: &totalPoints, waves: &scoringWaves, scoring: true)
            }
        }

        let heatBefore = heatH
        var heatReset = false
        if busted {
            unbanked = 0
            heatH = config.heatStart
        } else if scoringWaves > 0 {
            heatH = min(config.heatCap, heatH + config.heatStepPerWave * scoringWaves)
            unbanked += totalPoints
        } else if config.heatResetOnNoPop {
            heatH = config.heatStart
            heatReset = true
        }

        nextValue = drawValueRaw()

        return DropResolution(
            placedId: placed.id, placedCol: c, placedRow: placedRow, steps: steps,
            chainDepth: scoringWaves, pointsGained: totalPoints,
            heatBefore: heatBefore, heatAfter: heatH, heatReset: heatReset,
            busted: busted, unbankedAfter: unbanked, bankedAfter: bankedScore
        )
    }

    /// Lock in unbanked × heat; reset heat. Board is NOT cleared.
    @discardableResult
    func bank() -> Int {
        guard !isOver else { return bankedScore }
        bankedScore += unbanked * heatH / 100
        unbanked = 0
        heatH = config.heatStart
        return bankedScore
    }

    // MARK: resolution

    private func resolve(into steps: inout [ResolveStep], points: inout Int, waves: inout Int, scoring: Bool) {
        while true {
            // snapshot counts
            let colCount = columns.map { $0.count }
            var rowCount = [Int](repeating: 0, count: config.rows)
            for c in 0..<config.cols {
                for r in 0..<colCount[c] { rowCount[r] += 1 }
            }
            // find pops from the frozen snapshot
            var poppedByCol = Array(repeating: Set<Int>(), count: config.cols)
            var pops: [PopEvent] = []
            for c in 0..<config.cols {
                for r in 0..<columns[c].count {
                    if case .num(let v) = columns[c][r].kind, v == rowCount[r] || v == colCount[c] {
                        poppedByCol[c].insert(r)
                        pops.append(PopEvent(id: columns[c][r].id, col: c, row: r, value: v))
                    }
                }
            }
            if pops.isEmpty { break }

            waves += 1
            let depth = waves
            var wavePoints = 0
            if scoring {
                var per = config.scoreBase
                for _ in 1..<depth { per *= config.geo }
                wavePoints = per * pops.count
                if pops.count >= config.comboThreshold {
                    wavePoints += (pops.count - (config.comboThreshold - 1)) * config.comboBonusPer
                }
                points += wavePoints
            }

            // reveals: grays orthogonally adjacent to any popped cell
            var revealCells = Set<[Int]>()   // [col, row]
            for p in pops {
                for (dc, dr) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
                    let nc = p.col + dc, nr = p.row + dr
                    guard nc >= 0, nc < config.cols, nr >= 0, nr < columns[nc].count else { continue }
                    if columns[nc][nr].kind == .gray { revealCells.insert([nc, nr]) }
                }
            }
            var reveals: [RevealEvent] = []
            for cell in revealCells.sorted(by: { $0[0] != $1[0] ? $0[0] < $1[0] : $0[1] < $1[1] }) {
                let v = drawValueRaw()
                columns[cell[0]][cell[1]].kind = .num(v)
                reveals.append(RevealEvent(id: columns[cell[0]][cell[1]].id, col: cell[0], row: cell[1], value: v))
            }

            // remove popped + compute settle moves (column auto-collapses)
            var moves: [MoveEvent] = []
            for c in 0..<config.cols where !poppedByCol[c].isEmpty {
                var survivors: [Disc] = []
                for r in 0..<columns[c].count where !poppedByCol[c].contains(r) {
                    let newRow = survivors.count
                    if newRow != r { moves.append(MoveEvent(id: columns[c][r].id, col: c, fromRow: r, toRow: newRow)) }
                    survivors.append(columns[c][r])
                }
                columns[c] = survivors
            }

            steps.append(.wave(pops: pops, reveals: reveals, moves: moves, depth: depth, points: wavePoints))
        }
    }
}
