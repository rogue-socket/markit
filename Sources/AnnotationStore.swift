import Foundation
import CryptoKit

struct Annotation: Codable, Identifiable {
    let id: String
    let quote: String
    let contextBefore: String
    let contextAfter: String
    let comment: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, quote, comment
        case contextBefore = "context_before"
        case contextAfter = "context_after"
        case createdAt = "created_at"
    }
}

struct SidecarFile: Codable {
    let sourceFile: String
    let schemaVersion: Int
    var annotations: [Annotation]

    enum CodingKeys: String, CodingKey {
        case sourceFile = "source_file"
        case schemaVersion = "schema_version"
        case annotations
    }
}

final class AnnotationStore {
    private let sidecarPath: URL
    private var sidecar: SidecarFile

    var annotations: [Annotation] { sidecar.annotations }

    init(sourceFilePath: String) {
        let hash = SHA256.hash(data: Data(sourceFilePath.utf8))
        let hashString = hash.map { String(format: "%02x", $0) }.joined()

        let dir = AppPaths.annotationsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.sidecarPath = dir.appendingPathComponent("\(hashString).json")

        if let loaded = Self.loadSidecar(from: sidecarPath) {
            self.sidecar = loaded
        } else if FileManager.default.fileExists(atPath: sidecarPath.path) {
            fputs("markit: corrupt sidecar at \(sidecarPath.path), treating as empty\n", stderr)
            self.sidecar = SidecarFile(sourceFile: sourceFilePath, schemaVersion: 1, annotations: [])
        } else {
            self.sidecar = SidecarFile(sourceFile: sourceFilePath, schemaVersion: 1, annotations: [])
        }
    }

    func add(_ annotation: Annotation) {
        sidecar.annotations.append(annotation)
        persist()
    }

    func delete(id: String) {
        sidecar.annotations.removeAll { $0.id == id }
        persist()
    }

    func updateComment(id: String, comment: String) {
        guard let index = sidecar.annotations.firstIndex(where: { $0.id == id }) else { return }
        let annotation = sidecar.annotations[index]
        sidecar.annotations[index] = Annotation(
            id: annotation.id,
            quote: annotation.quote,
            contextBefore: annotation.contextBefore,
            contextAfter: annotation.contextAfter,
            comment: comment,
            createdAt: annotation.createdAt
        )
        persist()
    }

    func annotation(byId id: String) -> Annotation? {
        sidecar.annotations.first { $0.id == id }
    }

    private func persist() {
        guard let data = try? Self.makeEncoder().encode(sidecar) else { return }
        try? data.write(to: sidecarPath, options: .atomic)
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static func loadSidecar(from url: URL) -> SidecarFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? makeDecoder().decode(SidecarFile.self, from: data)
    }
}
