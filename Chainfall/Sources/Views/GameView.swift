import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                SpriteView(scene: vm.scene, options: [.ignoresSiblingOrder])
                    .aspectRatio(7.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if vm.isOver { gameOver }
        }
        .onAppear { vm.setReduceMotion(reduceMotion) }
        .onChange(of: reduceMotion) { _, v in vm.setReduceMotion(v) }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("banked").font(Type.instrumentMicro).foregroundStyle(Palette.onInkSecondary)
                Text("\(vm.banked)").font(Type.instrumentStd).monospacedDigit().foregroundStyle(Palette.onInkPrimary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(String(format: "×%.2f", vm.heat))
                    .font(Type.instrumentHero).monospacedDigit()
                    .foregroundStyle(Palette.heat(forMultiplier: vm.heat))
                    .animation(.easeOut(duration: 0.2), value: vm.heat)
                Text("heat").font(Type.instrumentMicro).foregroundStyle(Palette.onInkSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("rise in").font(Type.instrumentMicro).foregroundStyle(Palette.onInkSecondary)
                Text("\(vm.dropsUntilRise)").font(Type.instrumentStd).monospacedDigit()
                    .foregroundStyle(vm.dropsUntilRise <= 1 ? Palette.heat4 : Palette.onInkPrimary)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Palette.heat(forMultiplier: Double(vm.nextValue) * 0.7)).frame(width: 54, height: 54)
                Text("\(vm.nextValue)").font(Type.display(24, .bold)).foregroundStyle(Palette.ink)
            }
            Button { vm.bank() } label: {
                Text(vm.bankable > 0 ? "Bank \(vm.bankable)" : "Bank")
                    .font(Type.display(18, .bold)).foregroundStyle(Palette.onHeatGoldAmber)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.heat1))
            }
            .disabled(vm.bankable == 0 || vm.busy)
            .opacity(vm.bankable == 0 ? 0.45 : 1)
        }
    }

    private var gameOver: some View {
        ZStack {
            Palette.ink.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Busted").font(Type.h1).foregroundStyle(Palette.heat4)
                VStack(spacing: 2) {
                    Text("\(vm.banked)").font(Type.instrument(48, .semibold)).monospacedDigit().foregroundStyle(Palette.onInkPrimary)
                    Text("banked").font(Type.instrumentMicro).foregroundStyle(Palette.onInkSecondary)
                }
                Text("The floor caught your unbanked heat. Bank a little earlier next time.")
                    .font(Type.caption).multilineTextAlignment(.center).foregroundStyle(Palette.onInkSecondary)
                    .padding(.horizontal, 32)
                Button { vm.restart() } label: {
                    Text("Play again").font(Type.display(18, .bold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.paper))
                }
                .padding(.horizontal, 48).padding(.top, 6)
            }
            .padding(36)
        }
    }
}
