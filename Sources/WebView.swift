import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "selectionCaptured")

        let script = WKUserScript(source: Self.selectionJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(script)

        config.userContentController = ucc

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedContent != htmlContent else { return }
        webView.loadHTMLString(htmlContent, baseURL: nil)
        context.coordinator.loadedContent = htmlContent
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        var webView: WKWebView?
        var loadedContent: String?
        private var popover: NSPopover?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "selectionCaptured",
                  let body = message.body as? [String: Any],
                  let quote = body["quote"] as? String,
                  let contextBefore = body["contextBefore"] as? String,
                  let contextAfter = body["contextAfter"] as? String,
                  let rectDict = body["rect"] as? [String: Double] else { return }

            let x = rectDict["x"] ?? 0
            let y = rectDict["y"] ?? 0
            let width = rectDict["width"] ?? 0
            let height = rectDict["height"] ?? 0

            guard let webView = webView else { return }

            // Web viewport coords (top-left origin) → AppKit coords (bottom-left origin)
            let flippedY = webView.bounds.height - y - height
            let anchorRect = NSRect(x: x, y: flippedY, width: width, height: height)

            showCommentPopover(anchorRect: anchorRect, quote: quote, contextBefore: contextBefore, contextAfter: contextAfter)
        }

        private func showCommentPopover(anchorRect: NSRect, quote: String, contextBefore: String, contextAfter: String) {
            popover?.close()

            let pop = NSPopover()
            pop.behavior = .transient
            pop.contentSize = NSSize(width: 320, height: 200)

            let view = CommentPopoverView(
                quote: quote,
                onSave: { [weak self] comment in
                    self?.popover?.close()
                    print("--- Annotation ---")
                    print("Quote: \(quote)")
                    print("Context before: \(contextBefore)")
                    print("Context after: \(contextAfter)")
                    print("Comment: \(comment)")
                    print("------------------")
                },
                onCancel: { [weak self] in
                    self?.popover?.close()
                }
            )

            pop.contentViewController = NSHostingController(rootView: view)
            self.popover = pop

            guard let webView = webView else { return }
            pop.show(relativeTo: anchorRect, of: webView, preferredEdge: .maxY)
        }
    }

    // MARK: - Injected JavaScript

    static let selectionJS = """
    document.addEventListener('keydown', function(e) {
        if (e.metaKey && e.shiftKey && e.code === 'KeyC') {
            e.preventDefault();

            const selection = window.getSelection();
            if (!selection.rangeCount || selection.isCollapsed) return;

            const range = selection.getRangeAt(0);
            const quote = selection.toString();
            if (!quote.trim()) return;

            const body = document.body;

            // Context before (~30 chars)
            const preRange = document.createRange();
            preRange.setStart(body, 0);
            preRange.setEnd(range.startContainer, range.startOffset);
            const contextBefore = preRange.toString().slice(-30);

            // Context after (~30 chars)
            const postRange = document.createRange();
            postRange.setStart(range.endContainer, range.endOffset);
            postRange.setEnd(body, body.childNodes.length);
            const contextAfter = postRange.toString().slice(0, 30);

            // Bounding rect of selection
            const rect = range.getBoundingClientRect();

            window.webkit.messageHandlers.selectionCaptured.postMessage({
                quote: quote,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
            });
        }
    });
    """
}
