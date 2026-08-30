import Foundation

enum DocumentImportError: LocalizedError {
    case notPDF, inaccessible
    var errorDescription: String? {
        switch self {
        case .notPDF: "Yalnız PDF dosyaları içe aktarılabilir."
        case .inaccessible: "Seçilen dosyaya erişilemedi."
        }
    }
}

struct ImportedDocumentFile {
    let storedFileName: String
    let displayName: String
}

struct DocumentImportService {
    let rootDirectory: URL

    init(rootDirectory: URL? = nil) throws {
        if let rootDirectory { self.rootDirectory = rootDirectory }
        else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.rootDirectory = documents.appendingPathComponent("ImportedPDFs", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    func importPDF(from source: URL) throws -> ImportedDocumentFile {
        guard source.pathExtension.lowercased() == "pdf" else { throw DocumentImportError.notPDF }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.isReadableFile(atPath: source.path) else { throw DocumentImportError.inaccessible }
        let storedName = "\(UUID().uuidString).pdf"
        let destination = rootDirectory.appendingPathComponent(storedName)
        try FileManager.default.copyItem(at: source, to: destination)
        return ImportedDocumentFile(storedFileName: storedName, displayName: source.deletingPathExtension().lastPathComponent)
    }

    func url(for storedFileName: String) -> URL { rootDirectory.appendingPathComponent(storedFileName) }
    func delete(storedFileName: String) throws {
        let fileURL = url(for: storedFileName)
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }
}
