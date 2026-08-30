import AVFoundation
import Foundation

enum AudioServiceError: LocalizedError {
    case permissionDenied, noActiveRecording
    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Mikrofon izni verilmedi. Ayarlar'dan daha sonra değiştirebilirsiniz."
        case .noActiveRecording: "Etkin ses kaydı yok."
        }
    }
}

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    var permission: AVAudioApplication.recordPermission { AVAudioApplication.shared.recordPermission }

    func requestPermission() async -> Bool {
        if permission == .granted { return true }
        if permission == .denied { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    func start() throws -> String {
        guard permission == .granted else { throw AudioServiceError.permissionDenied }
        let folder = try Self.audioDirectory()
        let name = "\(UUID().uuidString).m4a"
        let url = folder.appendingPathComponent(name)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder?.record() == true else { throw AudioServiceError.noActiveRecording }
        startedAt = .now; elapsed = 0; isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed = self?.recorder?.currentTime ?? 0 }
        }
        return name
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause(); isPaused = true
    }

    func resume() {
        guard isRecording, isPaused else { return }
        recorder?.record(); isPaused = false
    }

    func stop() throws -> (fileName: String, duration: TimeInterval) {
        guard let recorder else { throw AudioServiceError.noActiveRecording }
        let name = recorder.url.lastPathComponent
        let duration = recorder.currentTime
        recorder.stop(); timer?.invalidate(); timer = nil; self.recorder = nil
        isRecording = false; isPaused = false; elapsed = duration; try? AVAudioSession.sharedInstance().setActive(false)
        return (name, duration)
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop(); recorder.deleteRecording(); timer?.invalidate(); timer = nil; self.recorder = nil
        isRecording = false; isPaused = false; elapsed = 0
    }

    static func audioDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("LectureAudio", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(for fileName: String) throws -> URL { try audioDirectory().appendingPathComponent(fileName) }
    static func delete(fileName: String) throws { try FileManager.default.removeItem(at: url(for: fileName)) }
}

enum AudioLifecycleState: Equatable { case idle, recording, paused, stopped }
enum AudioLifecycleEvent { case start, pause, resume, stop }

enum AudioLifecyclePolicy {
    static func transition(from state: AudioLifecycleState, event: AudioLifecycleEvent) -> AudioLifecycleState? {
        switch (state, event) {
        case (.idle, .start): .recording
        case (.recording, .pause): .paused
        case (.paused, .resume): .recording
        case (.recording, .stop), (.paused, .stop): .stopped
        default: nil
        }
    }
}

struct LocalAudioFileStore {
    let rootDirectory: URL
    func url(for fileName: String) -> URL { rootDirectory.appendingPathComponent(fileName) }
    func size(for fileName: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url(for: fileName).path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
    func delete(fileName: String) throws {
        let target = url(for: fileName)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
    }
}

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingFileName: String?
    private var player: AVAudioPlayer?
    func toggle(fileName: String) throws {
        if playingFileName == fileName { stop(); return }
        stop(); player = try AVAudioPlayer(contentsOf: AudioRecordingService.url(for: fileName)); player?.delegate = self; player?.play(); playingFileName = fileName
    }
    func stop() { player?.stop(); player = nil; playingFileName = nil }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor in self.stop() } }
}
