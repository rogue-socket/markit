# Project Instructions

## Commands
- Build executable only: `swift build`
- Build app bundle: `make build`
- Build release zip: `make dist`
- Dev run: `make run FILE=/absolute/path/to/file.md`
- Install app bundle: `make install`
- Clean build artifacts: `make clean`

No dedicated test, lint, or typecheck command is configured. Use `swift build` for compile/type checking and `make build` when app bundle packaging or `Resources/Info.plist` changes.

## Project Structure
- `Package.swift` - SwiftPM package for the `markit` executable, macOS 13+, Swift 5.9+, with `apple/swift-markdown`.
- `Sources/MarkitApp.swift` - SwiftUI app entry point and window sizing.
- `Sources/AppDelegate.swift` - file opening, CLI argument handling, markdown parsing, and app state hydration.
- `Sources/ContentView.swift` - main SwiftUI shell, empty/error states, HUD, and `WebView` hosting.
- `Sources/WebView.swift` - `WKWebView` bridge, injected JavaScript, selection handling, highlighting, popovers, and export messages.
- `Sources/MarkdownRenderer.swift` - markdown-to-HTML renderer.
- `Sources/AnnotationStore.swift` - annotation sidecar JSON persistence.
- `Sources/Config.swift` - app data paths and shortcut config loaded from `~/.markit/config.json`.
- `Resources/Info.plist` - app bundle metadata copied by `make build`.
- `markit` - CLI shim used by README install instructions.

## Working Style
- Make surgical changes and match the existing Swift/SwiftUI style.
- Keep the source markdown files read-only; the app stores annotations under `~/.markit/annotations/`.
- Keep shortcut behavior aligned between `Sources/Config.swift`, injected JavaScript in `Sources/WebView.swift`, and README documentation.
- Avoid broad rewrites of `Sources/WebView.swift`; changes there should be localized and manually verified because it contains the selection/highlight/export bridge.
- Do not reformat unrelated files or update screenshots unless the UI change requires it.

## Verification
- For most code changes, run `swift build`.
- For packaging, launch, `Info.plist`, or app bundle changes, run `make build`.
- For release archive changes, run `make dist`.
- For UI or annotation workflow changes, run `make run FILE=/absolute/path/to/sample.md` and check selection, comment save, highlight display, deletion, and export.
- `make run` terminates any running `markit` instance before relaunching.

## Safety
- Do not edit generated build output in `.build/` or `.swiftpm/`.
- Do not edit `Package.resolved` unless dependency changes require it.
- Do not delete or modify user data under `~/.markit/` unless explicitly asked.
- Ask before destructive filesystem, application install, or git operations.

## Session Docs
- No Claude handoffs or project memory were found to migrate during init.
- Use `$start` to create local `handoffs/` and `backlog.md` for Codex session tracking when needed.
