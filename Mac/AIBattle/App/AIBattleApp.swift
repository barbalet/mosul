import SwiftUI

@main
struct AIBattleApp: App {
    var body: some Scene {
        WindowGroup {
            AIBattleContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.titleBar)
    }
}
