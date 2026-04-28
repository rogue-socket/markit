import Markdown

struct MarkdownRenderer: MarkupVisitor {
    typealias Result = String

    private var isInTableHeader = false

    mutating func render(_ document: Document) -> String {
        let body = visit(document)
        return Self.wrapInHTML(body)
    }

    // MARK: - Default

    mutating func defaultVisit(_ markup: any Markup) -> String {
        renderChildren(markup)
    }

    // MARK: - Block Elements

    mutating func visitDocument(_ document: Document) -> String {
        renderChildren(document)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(heading.level, 6)
        let content = renderChildren(heading)
        return "<h\(level)>\(content)</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(renderChildren(paragraph))</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\(renderChildren(blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let code = escapeHTML(codeBlock.code)
        return "<pre><code>\(code)</code></pre>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let start = orderedList.startIndex
        let attr = start == 1 ? "" : " start=\"\(start)\""
        return "<ol\(attr)>\(renderChildren(orderedList))</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\(renderChildren(unorderedList))</ul>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        "<li>\(renderChildren(listItem))</li>"
    }

    // MARK: - Table Elements

    mutating func visitTable(_ table: Table) -> String {
        "<table>\(renderChildren(table))</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        isInTableHeader = true
        let content = renderChildren(tableHead)
        isInTableHeader = false
        return "<thead><tr>\(content)</tr></thead>"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        "<tbody>\(renderChildren(tableBody))</tbody>"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        "<tr>\(renderChildren(tableRow))</tr>"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let tag = isInTableHeader ? "th" : "td"
        return "<\(tag)>\(renderChildren(tableCell))</\(tag)>"
    }

    // MARK: - Inline Elements

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(renderChildren(emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(renderChildren(strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(renderChildren(strikethrough))</del>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = escapeHTML(link.destination ?? "")
        return "<a href=\"\(href)\">\(renderChildren(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = escapeHTML(image.source ?? "")
        let alt = escapeHTML(image.plainText)
        return "<img src=\"\(src)\" alt=\"\(alt)\">"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    // MARK: - Helpers

    private mutating func renderChildren(_ markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - HTML Template

    private static func wrapInHTML(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static let css = """
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
        max-width: 720px;
        margin: 0 auto;
        padding: 4px 8px;
        line-height: 1.6;
        color: #24292f;
        background: #ffffff;
        -webkit-font-smoothing: antialiased;
    }
    h1, h2, h3, h4, h5, h6 {
        margin-top: 24px;
        margin-bottom: 16px;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: #656d76; }
    p { margin-top: 0; margin-bottom: 16px; }
    a { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
    strong { font-weight: 600; }
    blockquote {
        margin: 0 0 16px 0;
        padding: 0 1em;
        border-left: 0.25em solid #d0d7de;
        color: #656d76;
    }
    code {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
        font-size: 85%;
        background: rgba(175, 184, 193, 0.2);
        padding: 0.2em 0.4em;
        border-radius: 6px;
    }
    pre {
        margin-bottom: 16px;
        padding: 16px;
        overflow: auto;
        font-size: 85%;
        line-height: 1.45;
        background: #f6f8fa;
        border: 1px solid #d0d7de;
        border-radius: 6px;
    }
    pre code {
        background: transparent;
        padding: 0;
        border-radius: 0;
        font-size: 100%;
    }
    ul, ol { margin-top: 0; margin-bottom: 16px; padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    li > p { margin-top: 16px; }
    li > p:first-child { margin-top: 0; }
    table {
        border-spacing: 0;
        border-collapse: collapse;
        margin-bottom: 16px;
        width: max-content;
        max-width: 100%;
        overflow: auto;
        display: block;
    }
    table th, table td {
        padding: 6px 13px;
        border: 1px solid #d0d7de;
    }
    table th { font-weight: 600; background: #f6f8fa; }
    table tr:nth-child(2n) { background: #f6f8fa; }
    hr {
        height: 0.25em;
        margin: 24px 0;
        padding: 0;
        background: #d0d7de;
        border: 0;
    }
    img { max-width: 100%; }
    del { text-decoration: line-through; }
    .mdgrill-hl {
        background: rgba(255, 212, 0, 0.3);
        padding: 0 2px;
        border-radius: 2px;
        cursor: pointer;
    }
    .mdgrill-hl:hover { background: rgba(255, 212, 0, 0.5); }
    @media (prefers-color-scheme: dark) {
        body { color: #e6edf3; background: #0d1117; }
        h1, h2 { border-color: #30363d; }
        h6 { color: #8b949e; }
        a { color: #58a6ff; }
        blockquote { border-color: #3b434b; color: #8b949e; }
        code { background: rgba(110, 118, 129, 0.4); }
        pre { background: #161b22; border-color: #30363d; }
        table th, table td { border-color: #30363d; }
        table th { background: #161b22; }
        table tr:nth-child(2n) { background: #161b22; }
        hr { background: #30363d; }
    }
    """
}
