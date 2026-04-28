import Foundation

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var htmlContent: String?
    @Published var errorMessage: String?
    @Published var sourceFilePath: String?
    @Published var annotationStore: AnnotationStore?
    @Published var orphanedCount: Int = 0

    private init() {}
}
