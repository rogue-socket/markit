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

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mdgrill/annotations")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.sidecarPath = dir.appendingPathComponent("\(hashString).json")

        if let data = try? Data(contentsOf: sidecarPath),
           let loaded = try? Self.makeDecoder().decode(SidecarFile.self, from: data) {
            self.sidecar = loaded
        } else {
            if FileManager.default.fileExists(atPath: sidecarPath.path) {
                fputs("mdgrill: corrupt sidecar at \(sidecarPath.path), treating as empty\n", stderr)
            }
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
}
