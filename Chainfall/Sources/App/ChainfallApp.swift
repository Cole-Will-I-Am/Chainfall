import SwiftUI

@main
struct ChainfallApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
                .tint(Palette.heat1)
        }
    }
}
