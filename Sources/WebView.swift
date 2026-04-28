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
        ucc.add(context.coordinator, name: "exportRequested")

        let js = Self.buildInjectedJS(config: AppState.shared.config)
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
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
            case "exportRequested":
                handleExport()
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

        // MARK: Export

        private func handleExport() {
            guard let store = AppState.shared.annotationStore else { return }
            let annotations = store.annotations
            guard !annotations.isEmpty else { return }

            let formatted = annotations.map { ann in
                "> \(ann.quote)\n\n\(ann.comment)\n\n---"
            }.joined(separator: "\n\n")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(formatted, forType: .string)

            AppState.shared.hudMessage = "\(annotations.count) annotation\(annotations.count == 1 ? "" : "s") copied"
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

            // WKWebView is flipped (isFlipped=true), so its coordinate system
            // matches web viewport coords: origin top-left, Y downward.
            return NSRect(x: x, y: y, width: width, height: height)
        }
    }

    // MARK: - Injected JavaScript

    static func buildInjectedJS(config: AppConfig) -> String {
    """
    const SHORTCUTS = \(config.jsConfigLiteral);

    function matchesShortcut(e, s) {
        return e.metaKey === s.meta && e.shiftKey === s.shift &&
               e.altKey === s.alt && e.ctrlKey === s.ctrl && e.code === s.code;
    }

    // --- Highlight painting ---
    function findQuotePosition(fullText, ann) {
        // Strategy 1: full triple match
        const triple = ann.context_before + ann.quote + ann.context_after;
        let idx = fullText.indexOf(triple);
        if (idx !== -1) {
            return idx + ann.context_before.length;
        }

        // Strategy 2: context_before + quote (without after)
        if (ann.context_before.length > 0) {
            const prefix = ann.context_before + ann.quote;
            idx = fullText.indexOf(prefix);
            if (idx !== -1) {
                return idx + ann.context_before.length;
            }
        }

        // Strategy 3: quote + context_after (without before)
        if (ann.context_after.length > 0) {
            const suffix = ann.quote + ann.context_after;
            idx = fullText.indexOf(suffix);
            if (idx !== -1) {
                return idx;
            }
        }

        // Strategy 4: just the quote (use first occurrence)
        idx = fullText.indexOf(ann.quote);
        if (idx !== -1) {
            // If multiple occurrences, try to disambiguate with partial context
            const nextIdx = fullText.indexOf(ann.quote, idx + 1);
            if (nextIdx === -1) {
                return idx; // unique match
            }
            // Ambiguous: try matching with shorter context
            for (let ctx = ann.context_before.length; ctx >= 5; ctx -= 5) {
                const partialBefore = ann.context_before.slice(-ctx);
                const search = partialBefore + ann.quote;
                const found = fullText.indexOf(search);
                if (found !== -1) {
                    return found + partialBefore.length;
                }
            }
            return idx; // fall back to first occurrence
        }

        return -1; // truly orphaned
    }

    function paintHighlights(annotations) {
        let orphanedCount = 0;

        for (const ann of annotations) {
            const fullText = document.body.textContent;
            const quoteStart = findQuotePosition(fullText, ann);

            if (quoteStart === -1) {
                orphanedCount++;
                continue;
            }

            const quoteEnd = quoteStart + ann.quote.length;

            // Collect text nodes with their global offsets
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let currentOffset = 0;
            const textNodes = [];
            let node;

            while (node = walker.nextNode()) {
                const len = node.textContent.length;
                textNodes.push({ node: node, start: currentOffset, end: currentOffset + len });
                currentOffset += len;
                if (currentOffset >= quoteEnd) break;
            }

            // Find which text nodes overlap with the quote range
            const overlapping = textNodes.filter(tn => tn.end > quoteStart && tn.start < quoteEnd);

            if (overlapping.length === 0) {
                orphanedCount++;
                continue;
            }

            // Wrap each overlapping text node (or portion) in a highlight span
            let painted = false;
            for (const tn of overlapping) {
                const wrapStart = Math.max(0, quoteStart - tn.start);
                const wrapEnd = Math.min(tn.node.textContent.length, quoteEnd - tn.start);
                if (wrapStart >= wrapEnd) continue;

                // Skip whitespace-only segments (newlines between block elements)
                const segment = tn.node.textContent.substring(wrapStart, wrapEnd);
                if (!segment.trim()) continue;

                try {
                    const r = document.createRange();
                    r.setStart(tn.node, wrapStart);
                    r.setEnd(tn.node, wrapEnd);
                    const span = document.createElement('span');
                    span.className = 'mdgrill-hl';
                    span.dataset.annId = ann.id;
                    r.surroundContents(span);
                    painted = true;
                } catch (e) {}
            }

            if (!painted) orphanedCount++;
        }

        return orphanedCount;
    }

    // --- Remove highlight ---
    function removeHighlight(annId) {
        const spans = document.querySelectorAll('.mdgrill-hl[data-ann-id=\"' + annId + '\"]');
        spans.forEach(function(span) {
            const parent = span.parentNode;
            while (span.firstChild) {
                parent.insertBefore(span.firstChild, span);
            }
            parent.removeChild(span);
            parent.normalize();
        });
    }

    // --- Selection capture ---
    document.addEventListener('keydown', function(e) {
        if (matchesShortcut(e, SHORTCUTS.add_comment)) {
            e.preventDefault();

            const selection = window.getSelection();
            if (!selection.rangeCount || selection.isCollapsed) return;

            const range = selection.getRangeAt(0);
            // Use range.toString() (not selection.toString()) for consistency
            // with textContent used during highlight re-painting.
            const quote = range.toString();
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

    // --- Export ---
    document.addEventListener('keydown', function(e) {
        if (matchesShortcut(e, SHORTCUTS.export)) {
            e.preventDefault();
            window.webkit.messageHandlers.exportRequested.postMessage({});
        }
    });
    """
    }
}
