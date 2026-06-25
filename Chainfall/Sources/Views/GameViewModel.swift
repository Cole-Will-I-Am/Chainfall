import SwiftUI

/// Owns the engine + the published state for the SwiftUI overlay, and drives the scene.
/// The engine is the source of truth; the scene is a pure projector of its events.
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var banked = 0
    @Published private(set) var heat = 1.0
    @Published private(set) var bankable = 0
    @Published private(set) var nextValue = 1
    @Published private(set) var dropsUntilRise = 6
    @Published private(set) var isOver = false
    @Published private(set) var busy = false          // input locked while a cascade animates

    let scene: WellScene
    private let config = GameConfig()
    private var game: ChainfallGame

    init() {
        let seed = UInt64.random(in: 1 ... .max)
        game = ChainfallGame(seed: seed, config: config)
        scene = WellScene(size: CGSize(width: 700, height: 900), config: config)
        scene.onColumnTap = { [weak self] col in self?.drop(column: col) }
        scene.setBoard(game.columns)
        sync()
    }

    func setReduceMotion(_ on: Bool) { scene.reduceMotion = on }

    func drop(column c: Int) {
        guard !busy, !isOver else { return }
        let droppedValue = game.nextValue
        guard let res = game.drop(column: c) else { return }
        busy = true
        nextValue = game.nextValue
        scene.play(res, droppedValue: droppedValue, completion: { [weak self] in
            guard let self else { return }
            self.busy = false
            self.sync()
        })
    }

    func bank() {
        guard !busy, !isOver, game.unbanked > 0 else { return }
        Haptics.bank()
        game.bank()
        scene.flashBank()
        sync()
    }

    func restart() {
        let seed = UInt64.random(in: 1 ... .max)
        game = ChainfallGame(seed: seed, config: config)
        scene.setBoard(game.columns)
        busy = false
        sync()
    }

    private func sync() {
        banked = game.bankedScore
        heat = game.heatMultiplier
        bankable = game.bankable
        nextValue = game.nextValue
        dropsUntilRise = config.threatPeriod - (game.dropCount % config.threatPeriod)
        isOver = game.isOver
    }
}
