import SwiftUI
import SwiftData

@main
struct NEXUSStudyPadApp: App {
    private let container: ModelContainer

    init() {
        do { container = try PersistenceController.makeContainer() }
        catch { fatalError("NEXUS STUDY PAD yerel veri deposu açılamadı: \(error)") }
    }

    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark) }
            .modelContainer(container)
    }
}
