import SwiftUI

@main
struct MarkitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState.shared)
                .frame(minWidth: 400, minHeight: 300)
                .onAppear { setDefaultWindowSize() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    private func setDefaultWindowSize() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        if let window = NSApp.windows.first {
            let width = window.frame.width
            let newFrame = NSRect(
                x: window.frame.origin.x,
                y: visibleFrame.origin.y,
                width: width,
                height: visibleFrame.height
            )
            window.setFrame(newFrame, display: true)
        }
    }
}
