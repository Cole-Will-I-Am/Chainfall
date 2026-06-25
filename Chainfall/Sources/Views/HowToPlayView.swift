import SwiftUI

/// The rules — shown automatically on first launch and always reachable from the "?" on
/// the game screen. Dark, to match the well.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("How to play").font(Type.h1).foregroundStyle(Palette.onInkPrimary)
                    Spacer()
                    Button("Done") { dismiss() }.font(Type.body).foregroundStyle(Palette.heat1)
                }

                section("The goal",
                        "Drop numbered discs into the 7-wide well. Set off chain reactions to score — then bank your points before the rising floor buries you.")
                section("Discs pop on a match",
                        "A disc pops when its number equals how many discs are in its row, or in its column. So a 3 pops when there are exactly three discs across its row or stacked in its column.")
                section("Chains",
                        "When discs pop, everything above falls — and that can line up new matches that pop too. Each wave is a chain link, and deep chains are where the big points (and heat) come from.")
                section("Heat × — your momentum",
                        "Every chain lifts your heat multiplier. But a drop that pops nothing resets heat to ×1.00. Heat is momentum you build… and can lose in one dead drop.")
                section("Bank, or push your luck",
                        "Your chain points sit unbanked. Tap Bank to lock in unbanked × heat (heat then resets). The gamble: push for a bigger chain and higher heat, or bank before a dead drop or the floor wipes it.")
                section("The rising floor",
                        "Every few drops a gray row rises from the bottom and shoves everything up — watch “rise in”. If a column is pushed over the top, you’re busted and all unbanked heat is gone. Bank before that happens.")
                section("A tip",
                        "Bank when your heat is high and you’re not sure the next drop will chain. A small sure thing beats a big maybe.")
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink.ignoresSafeArea())
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Type.h2).foregroundStyle(Palette.onInkPrimary)
            Text(body).font(Type.body).foregroundStyle(Palette.onInkSecondary)
        }
    }
}
