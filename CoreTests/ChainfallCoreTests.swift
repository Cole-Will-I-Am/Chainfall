import XCTest
@testable import ChainfallCore

final class ChainfallCoreTests: XCTestCase {

    func testSplitMix64Reference() {
        var r = SplitMix64(seed: 0)
        XCTAssertEqual(r.next(), 0xE220_A839_7B1D_CDAF)   // matches RUNG's PRNG
    }

    /// The property the server anti-cheat relies on: same seed + same moves → identical
    /// outcome, bit-for-bit.
    func testReplayDeterminism() {
        let cols = [3, 3, 4, 0, 6, 1, 2, 2, 5, 4, 0, 3, 6, 1, 5, 2, 4, 3, 0, 6]
        let a = ChainfallGame(seed: 42)
        let b = ChainfallGame(seed: 42)
        for c in cols {
            let ra = a.drop(column: c)
            let rb = b.drop(column: c)
            XCTAssertEqual(ra, rb)
        }
        XCTAssertEqual(a.bankedScore, b.bankedScore)
        XCTAssertEqual(a.heatH, b.heatH)
        XCTAssertEqual(a.columns, b.columns)
    }

    /// Columns stay contiguous (no floating gaps) and never exceed the well height.
    func testInvariants() {
        let g = ChainfallGame(seed: 7)
        var i = 0
        while !g.isOver && i < 400 {
            let c = i % g.config.cols
            if g.columnHeight(c) >= g.config.rows { i += 1; continue }
            _ = g.drop(column: c)
            for col in 0..<g.config.cols { XCTAssertLessThanOrEqual(g.columnHeight(col), g.config.rows) }
            XCTAssertGreaterThanOrEqual(g.bankedScore, 0)
            i += 1
        }
    }

    /// On an empty board a single disc pops iff its value is 1 (row-count = col-count = 1).
    func testColumnPopOnEmptyBoard() {
        var cfg = GameConfig(); cfg.initialRows = 0
        var seed: UInt64 = 0
        var g = ChainfallGame(seed: 0, config: cfg)
        while g.nextValue != 1 && seed < 500 { seed += 1; g = ChainfallGame(seed: seed, config: cfg) }
        XCTAssertEqual(g.nextValue, 1, "couldn't find a seed yielding a leading 1")
        let res = g.drop(column: 0)!
        XCTAssertEqual(res.chainDepth, 1)
        XCTAssertTrue(g.columns[0].isEmpty)               // the 1 cleared itself
        XCTAssertEqual(res.pointsGained, cfg.scoreBase)   // 1 disc, wave 1 → scoreBase
        XCTAssertEqual(g.heatH, cfg.heatStart + cfg.heatStepPerWave) // heat rose one wave
    }

    /// A no-pop drop resets heat (the tension lever); a banked run locks unbanked × heat.
    func testHeatResetAndBank() {
        let g = ChainfallGame(seed: 99)
        var sawReset = false
        var i = 0
        while !g.isOver && i < 300 {
            let c = i % g.config.cols
            if g.columnHeight(c) >= g.config.rows { i += 1; continue }
            if let r = g.drop(column: c), r.heatReset {
                XCTAssertEqual(r.chainDepth, 0)
                XCTAssertEqual(g.heatH, g.config.heatStart)
                sawReset = true
                break
            }
            i += 1
        }
        XCTAssertTrue(sawReset, "expected at least one no-pop drop to reset heat")

        // Drive some unbanked + heat, then bank.
        let g2 = ChainfallGame(seed: 3)
        var n = 0
        while g2.unbanked == 0 && !g2.isOver && n < 200 { _ = g2.drop(column: n % g2.config.cols); n += 1 }
        let expected = g2.bankedScore + g2.unbanked * g2.heatH / 100
        g2.bank()
        XCTAssertEqual(g2.bankedScore, expected)
        XCTAssertEqual(g2.unbanked, 0)
        XCTAssertEqual(g2.heatH, g2.config.heatStart)
    }
}
