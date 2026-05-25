import Foundation

enum AppPaths {
    static let appDirectoryName = ".markit"

    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var appDirectory: URL {
        homeDirectory.appendingPathComponent(appDirectoryName)
    }

    static var configFile: URL {
        appDirectory.appendingPathComponent("config.json")
    }

    static var annotationsDirectory: URL {
        appDirectory.appendingPathComponent("annotations")
    }
}

struct ShortcutConfig {
    let meta: Bool
    let shift: Bool
    let alt: Bool
    let ctrl: Bool
    let code: String // JS key code like "KeyC", "KeyE"
}

struct AppConfig {
    let addComment: ShortcutConfig
    let export: ShortcutConfig

    static let `default` = AppConfig(
        addComment: ShortcutConfig(meta: true, shift: true, alt: false, ctrl: false, code: "KeyC"),
        export: ShortcutConfig(meta: true, shift: false, alt: false, ctrl: false, code: "KeyE")
    )

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: AppPaths.configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shortcuts = json["shortcuts"] as? [String: String] else {
            return .default
        }

        let addComment = shortcuts["add_comment"].flatMap { parse($0) } ?? Self.default.addComment
        let export = shortcuts["export"].flatMap { parse($0) } ?? Self.default.export

        return AppConfig(addComment: addComment, export: export)
    }

    private static func parse(_ shortcut: String) -> ShortcutConfig? {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard parts.count >= 2 else { return nil }

        var meta = false, shift = false, alt = false, ctrl = false
        var key: String?

        for part in parts {
            switch part {
            case "cmd", "meta", "command":
                meta = true
            case "shift":
                shift = true
            case "alt", "option", "opt":
                alt = true
            case "ctrl", "control":
                ctrl = true
            default:
                key = part
            }
        }

        guard let k = key, k.count == 1, k.first!.isLetter else { return nil }
        let code = "Key\(k.uppercased())"
        return ShortcutConfig(meta: meta, shift: shift, alt: alt, ctrl: ctrl, code: code)
    }

    /// Returns JS object literal for embedding in injected script
    var jsConfigLiteral: String {
        """
        {
            add_comment: { meta: \(addComment.meta), shift: \(addComment.shift), alt: \(addComment.alt), ctrl: \(addComment.ctrl), code: "\(addComment.code)" },
            export: { meta: \(export.meta), shift: \(export.shift), alt: \(export.alt), ctrl: \(export.ctrl), code: "\(export.code)" }
        }
        """
    }
}
