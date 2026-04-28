import AppKit
import Markdown

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        loadFile(at: url)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Handle file passed as command-line argument (e.g., open App.app --args file.md)
        let args = ProcessInfo.processInfo.arguments
        if args.count > 1 {
            let path = args[1]
            let url = URL(fileURLWithPath: path).standardized
            // Defer to next run loop so SwiftUI view is ready to observe state changes
            DispatchQueue.main.async {
                self.loadFile(at: url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        true
    }

    private func loadFile(at url: URL) {
        let path = url.path

        guard FileManager.default.fileExists(atPath: path) else {
            AppState.shared.errorMessage = "File not found:\n\(path)"
            return
        }

        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            AppState.shared.errorMessage = "Cannot read file (not valid UTF-8):\n\(path)"
            return
        }

        let document = Document(parsing: content)
        var renderer = MarkdownRenderer()
        let html = renderer.render(document)

        AppState.shared.sourceFilePath = path
        AppState.shared.htmlContent = html
        AppState.shared.errorMessage = nil

        // Focus existing window
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
