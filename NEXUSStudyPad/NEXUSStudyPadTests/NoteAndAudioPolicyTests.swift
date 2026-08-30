import XCTest
@testable import NEXUSStudyPad

final class NoteAndAudioPolicyTests: XCTestCase {
    func testLongNotePolicyAcceptsPagesAndRejectsOnlyOverSafetyLimit() {
        XCTAssertTrue(NoteContentPolicy.isValid(body: String(repeating: "uzun not satırı\n", count: 20_000)))
        XCTAssertFalse(NoteContentPolicy.isValid(body: String(repeating: "a", count: NoteContentPolicy.maximumUTF8Bytes + 1)))
    }

    func testAudioLifecycleSupportsPauseResumeStopAndRejectsInvalidTransitions() {
        XCTAssertEqual(AudioLifecyclePolicy.transition(from: .idle, event: .start), .recording)
        XCTAssertEqual(AudioLifecyclePolicy.transition(from: .recording, event: .pause), .paused)
        XCTAssertEqual(AudioLifecyclePolicy.transition(from: .paused, event: .resume), .recording)
        XCTAssertEqual(AudioLifecyclePolicy.transition(from: .paused, event: .stop), .stopped)
        XCTAssertNil(AudioLifecyclePolicy.transition(from: .idle, event: .pause))
    }

    func testLocalAudioFileMetadataAndDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalAudioFileStore(rootDirectory: root); let name = "test.m4a"
        try Data(repeating: 7, count: 128).write(to: store.url(for: name))
        XCTAssertEqual(store.size(for: name), 128)
        try store.delete(fileName: name)
        XCTAssertEqual(store.size(for: name), 0)
    }
}
