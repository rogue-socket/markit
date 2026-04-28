import SwiftUI

@main
struct mdgrillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState.shared)
                .frame(minWidth: 400, minHeight: 300)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
