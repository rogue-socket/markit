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
                ZStack(alignment: .bottomTrailing) {
                    WebView(htmlContent: html)

                    if appState.orphanedCount > 0 {
                        Text("\(appState.orphanedCount) orphaned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }

                    if let hud = appState.hudMessage {
                        hudView(hud)
                            .transition(.opacity)
                    }
                }
            } else {
                emptyState
            }
        }
        .alert("Error", isPresented: showingError) {
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onChange(of: appState.hudMessage) { message in
            if message != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { appState.hudMessage = nil }
                }
            }
        }
    }

    private func hudView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
