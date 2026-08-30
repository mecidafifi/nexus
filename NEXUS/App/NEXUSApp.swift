import SwiftUI
import SwiftData
import AppKit

final class NEXUSApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct NEXUSApp: App {
    @NSApplicationDelegateAdaptor(NEXUSApplicationDelegate.self) private var applicationDelegate
    @StateObject private var appState = AppState()
    private let container: ModelContainer

    init() {
        do { container = try PersistenceController.makeContainer() }
        catch { fatalError("NEXUS local store could not be created: \(error)") }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(appState)
                .modelContainer(container)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .commands { NEXUSCommands(appState: appState) }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .modelContainer(container)
        }

        MenuBarExtra {
            VoiceMenuBarView()
                .environmentObject(appState)
                .modelContainer(container)
        } label: {
            VoiceMenuBarLabel().environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
