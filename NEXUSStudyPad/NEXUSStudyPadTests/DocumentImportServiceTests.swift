import XCTest
@testable import NEXUSStudyPad

final class DocumentImportServiceTests: XCTestCase {
    private var temp: URL!
    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: temp) }

    func testUserSelectedPDFIsCopiedAndCanBeDeleted() throws {
        let source = temp.appendingPathComponent("Ders Notu.pdf")
        try Data("%PDF-1.4\n%%EOF".utf8).write(to: source)
        let destinationRoot = temp.appendingPathComponent("Imported", isDirectory: true)
        let service = try DocumentImportService(rootDirectory: destinationRoot)
        let imported = try service.importPDF(from: source)
        XCTAssertEqual(imported.displayName, "Ders Notu")
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.url(for: imported.storedFileName).path))
        try service.delete(storedFileName: imported.storedFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.url(for: imported.storedFileName).path))
    }

    func testNonPDFIsRejectedWithoutCopy() throws {
        let source = temp.appendingPathComponent("not.txt")
        try Data("text".utf8).write(to: source)
        let service = try DocumentImportService(rootDirectory: temp.appendingPathComponent("Imported"))
        XCTAssertThrowsError(try service.importPDF(from: source))
    }
}
