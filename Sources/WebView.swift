import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.loadedContent = nil
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedContent != htmlContent else { return }
        webView.loadHTMLString(htmlContent, baseURL: nil)
        context.coordinator.loadedContent = htmlContent
    }

    class Coordinator {
        var loadedContent: String?
    }
}
