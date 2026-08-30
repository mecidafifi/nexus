import SwiftUI

struct NEXUSCommands: Commands {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("settings.menuTitle") { openSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(appState.appLock.blocksAccess)
        }
        CommandMenu("menu.navigation") {
            Button("command.home") { appState.handleEscape() }.keyboardShortcut(.escape, modifiers: [])
                .disabled(appState.appLock.blocksAccess)
            Divider()
            ForEach(AppRoute.allCases) { route in
                Button { appState.open(route) } label: { Text(LocalizedStringKey(route.titleKey)) }
                    .keyboardShortcut(KeyEquivalent(Character(String(route.number))), modifiers: [])
                    .disabled(appState.appLock.blocksAccess)
            }
        }
        CommandGroup(replacing: .newItem) {
            Button("command.new") { NotificationCenter.default.post(name: .nexusNewItem, object: nil) }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(appState.appLock.blocksAccess)
        }
        CommandGroup(after: .newItem) {
            Button("briefing.title") { appState.openMorningBriefing() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(appState.appLock.blocksAccess)
            Button("quickEntry.title") { appState.openQuickEntry() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(appState.appLock.blocksAccess)
            Button("evening.title") {
                appState.closeControlSystem()
                NotificationCenter.default.post(name: .nexusEveningReview, object: nil)
            }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.appLock.blocksAccess || appState.route != nil)
            Button("voice.title") { appState.openVoiceAssistant() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(appState.appLock.blocksAccess)
            Button("command.save") { NotificationCenter.default.post(name: .nexusSave, object: nil) }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.appLock.blocksAccess)
        }
        CommandGroup(after: .textEditing) {
            Button("command.search") { NotificationCenter.default.post(name: .nexusFocusSearch, object: nil) }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(appState.appLock.blocksAccess)
            Button("command.controlSystemSearch") { appState.openControlSystem(mode: .search) }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(appState.appLock.blocksAccess || appState.bootSequence.isBooting)
            Button("command.palette") { appState.toggleControlSystem() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(appState.appLock.blocksAccess || appState.bootSequence.isBooting)
        }
    }
}
