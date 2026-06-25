import XCTest
@testable import Chainfall

/// iOS-target smoke tests (run on the simulator in CI). The deep engine coverage lives in
/// CoreTests (Linux `swift test`); this just guards that the engine compiles + runs in
/// the app module and stays deterministic.
final class ChainfallTests: XCTestCase {
    func testSplitMix64Reference() {
        var r = SplitMix64(seed: 0)
        XCTAssertEqual(r.next(), 0xE220_A839_7B1D_CDAF)
    }

    func testDeterministicReplay() {
        let moves = [3, 3, 4, 0, 6, 1, 2, 5, 4, 0]
        let a = ChainfallGame(seed: 5), b = ChainfallGame(seed: 5)
        for c in moves { XCTAssertEqual(a.drop(column: c), b.drop(column: c)) }
        XCTAssertEqual(a.bankedScore, b.bankedScore)
        XCTAssertEqual(a.heatH, b.heatH)
    }

    func testBankResetsHeat() {
        let g = ChainfallGame(seed: 8)
        var n = 0
        while g.unbanked == 0 && !g.isOver && n < 200 { _ = g.drop(column: n % 7); n += 1 }
        g.bank()
        XCTAssertEqual(g.unbanked, 0)
        XCTAssertEqual(g.heatH, g.config.heatStart)
    }
}
