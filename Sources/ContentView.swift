import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private var showingError: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { NSApp.terminate(nil) } }
        )
    }

    var body: some View {
        Group {
            if let html = appState.htmlContent {
                WebView(htmlContent: html)
            } else {
                emptyState
            }
        }
        .alert("Error", isPresented: showingError) {
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("mdgrill")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Open a file: mdgrill path/to/file.md")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
