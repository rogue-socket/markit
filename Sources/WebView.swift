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
        ucc.add(context.coordinator, name: "highlightClicked")

        let script = WKUserScript(source: Self.injectedJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(script)

        config.userContentController = ucc

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedContent != htmlContent else { return }
        webView.loadHTMLString(htmlContent, baseURL: nil)
        context.coordinator.loadedContent = htmlContent
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var webView: WKWebView?
        var loadedContent: String?
        private var popover: NSPopover?

        // MARK: Navigation delegate — paint highlights after load

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            paintAllHighlights()
        }

        // MARK: Message handler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "selectionCaptured":
                handleSelectionCaptured(message.body)
            case "highlightClicked":
                handleHighlightClicked(message.body)
            default:
                break
            }
        }

        // MARK: Selection captured → new annotation popover

        private func handleSelectionCaptured(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let quote = dict["quote"] as? String,
                  let contextBefore = dict["contextBefore"] as? String,
                  let contextAfter = dict["contextAfter"] as? String,
                  let rectDict = dict["rect"] as? [String: Double] else { return }

            let anchorRect = rectFromDict(rectDict)
            showNewCommentPopover(anchorRect: anchorRect, quote: quote, contextBefore: contextBefore, contextAfter: contextAfter)
        }

        private func showNewCommentPopover(anchorRect: NSRect, quote: String, contextBefore: String, contextAfter: String) {
            popover?.close()

            let pop = NSPopover()
            pop.behavior = .transient
            pop.contentSize = NSSize(width: 320, height: 200)

            let view = CommentPopoverView(
                quote: quote,
                onSave: { [weak self] comment in
                    self?.popover?.close()
                    self?.saveAnnotation(quote: quote, contextBefore: contextBefore, contextAfter: contextAfter, comment: comment)
                },
                onDismiss: { [weak self] in
                    self?.popover?.close()
                }
            )

            pop.contentViewController = NSHostingController(rootView: view)
            self.popover = pop

            guard let webView = webView else { return }
            pop.show(relativeTo: anchorRect, of: webView, preferredEdge: .maxY)
        }

        private func saveAnnotation(quote: String, contextBefore: String, contextAfter: String, comment: String) {
            guard let store = AppState.shared.annotationStore else { return }

            let annotation = Annotation(
                id: UUID().uuidString,
                quote: quote,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                comment: comment,
                createdAt: Date()
            )
            store.add(annotation)

            // Paint the new highlight in the webview
            paintHighlights([annotation])
        }

        // MARK: Highlight clicked → view annotation popover

        private func handleHighlightClicked(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let annId = dict["id"] as? String,
                  let rectDict = dict["rect"] as? [String: Double] else { return }

            guard let store = AppState.shared.annotationStore,
                  let annotation = store.annotation(byId: annId) else { return }

            let anchorRect = rectFromDict(rectDict)
            showViewCommentPopover(anchorRect: anchorRect, annotation: annotation)
        }

        private func showViewCommentPopover(anchorRect: NSRect, annotation: Annotation) {
            popover?.close()

            let pop = NSPopover()
            pop.behavior = .transient
            pop.contentSize = NSSize(width: 320, height: 160)

            let view = CommentPopoverView(
                quote: annotation.quote,
                existingComment: annotation.comment,
                onDelete: { [weak self] in
                    self?.popover?.close()
                    self?.deleteAnnotation(id: annotation.id)
                },
                onDismiss: { [weak self] in
                    self?.popover?.close()
                }
            )

            pop.contentViewController = NSHostingController(rootView: view)
            self.popover = pop

            guard let webView = webView else { return }
            pop.show(relativeTo: anchorRect, of: webView, preferredEdge: .maxY)
        }

        private func deleteAnnotation(id: String) {
            AppState.shared.annotationStore?.delete(id: id)

            let js = "removeHighlight('\(id)')"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: Highlight painting

        private func paintAllHighlights() {
            guard let store = AppState.shared.annotationStore else { return }
            paintHighlights(store.annotations)
        }

        private func paintHighlights(_ annotations: [Annotation]) {
            guard let webView = webView, !annotations.isEmpty else { return }

            guard let jsonData = try? AnnotationStore.makeEncoder().encode(annotations),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let js = "paintHighlights(\(jsonString))"
            webView.evaluateJavaScript(js) { result, _ in
                if let orphaned = result as? Int {
                    DispatchQueue.main.async {
                        AppState.shared.orphanedCount = orphaned
                    }
                }
            }
        }

        // MARK: Helpers

        private func rectFromDict(_ dict: [String: Double]) -> NSRect {
            let x = dict["x"] ?? 0
            let y = dict["y"] ?? 0
            let width = dict["width"] ?? 0
            let height = dict["height"] ?? 0

            guard let webView = webView else { return .zero }

            // Web viewport coords (top-left origin) → AppKit coords (bottom-left origin)
            let flippedY = webView.bounds.height - y - height
            return NSRect(x: x, y: flippedY, width: width, height: height)
        }
    }

    // MARK: - Injected JavaScript

    static let injectedJS = """
    // --- Highlight painting ---
    function paintHighlights(annotations) {
        let orphanedCount = 0;

        for (const ann of annotations) {
            const fullText = document.body.textContent;
            const searchStr = ann.context_before + ann.quote + ann.context_after;
            const idx = fullText.indexOf(searchStr);

            if (idx === -1) {
                orphanedCount++;
                continue;
            }

            const quoteStart = idx + ann.context_before.length;
            const quoteEnd = quoteStart + ann.quote.length;

            // Map global text offset to DOM text node + local offset
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let currentOffset = 0;
            let startNode = null, startOff = 0, endNode = null, endOff = 0;
            let node;

            while (node = walker.nextNode()) {
                const len = node.textContent.length;
                if (!startNode && currentOffset + len > quoteStart) {
                    startNode = node;
                    startOff = quoteStart - currentOffset;
                }
                if (!endNode && currentOffset + len >= quoteEnd) {
                    endNode = node;
                    endOff = quoteEnd - currentOffset;
                    break;
                }
                currentOffset += len;
            }

            if (!startNode || !endNode) {
                orphanedCount++;
                continue;
            }

            try {
                const range = document.createRange();
                range.setStart(startNode, startOff);
                range.setEnd(endNode, endOff);

                const span = document.createElement('span');
                span.className = 'mdgrill-hl';
                span.dataset.annId = ann.id;
                range.surroundContents(span);
            } catch (e) {
                orphanedCount++;
            }
        }

        return orphanedCount;
    }

    // --- Remove highlight ---
    function removeHighlight(annId) {
        const span = document.querySelector('.mdgrill-hl[data-ann-id=\"' + annId + '\"]');
        if (span) {
            const parent = span.parentNode;
            while (span.firstChild) {
                parent.insertBefore(span.firstChild, span);
            }
            parent.removeChild(span);
            parent.normalize();
        }
    }

    // --- Selection capture (Cmd+Shift+C) ---
    document.addEventListener('keydown', function(e) {
        if (e.metaKey && e.shiftKey && e.code === 'KeyC') {
            e.preventDefault();

            const selection = window.getSelection();
            if (!selection.rangeCount || selection.isCollapsed) return;

            const range = selection.getRangeAt(0);
            const quote = selection.toString();
            if (!quote.trim()) return;

            const body = document.body;

            const preRange = document.createRange();
            preRange.setStart(body, 0);
            preRange.setEnd(range.startContainer, range.startOffset);
            const contextBefore = preRange.toString().slice(-30);

            const postRange = document.createRange();
            postRange.setStart(range.endContainer, range.endOffset);
            postRange.setEnd(body, body.childNodes.length);
            const contextAfter = postRange.toString().slice(0, 30);

            const rect = range.getBoundingClientRect();

            window.webkit.messageHandlers.selectionCaptured.postMessage({
                quote: quote,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
            });
        }
    });

    // --- Highlight click handler ---
    document.addEventListener('click', function(e) {
        const hl = e.target.closest('.mdgrill-hl');
        if (hl) {
            const annId = hl.dataset.annId;
            const rect = hl.getBoundingClientRect();
            window.webkit.messageHandlers.highlightClicked.postMessage({
                id: annId,
                rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
            });
        }
    });
    """
}
