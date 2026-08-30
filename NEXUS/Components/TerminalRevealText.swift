import SwiftUI

struct TerminalRevealProgress: Equatable {
    let finalText: String
    private(set) var visibleCharacterCount = 0

    var isComplete: Bool { visibleCharacterCount >= finalText.count }
    var visibleText: String { String(finalText.prefix(visibleCharacterCount)) }

    mutating func advance(by amount: Int = 1) {
        visibleCharacterCount = min(finalText.count, visibleCharacterCount + max(0, amount))
    }

    mutating func complete() {
        visibleCharacterCount = finalText.count
    }
}

/// A silent reveal for NEXUS-generated labels. Editable/user-authored content
/// must continue to use TextField/TextEditor/Text directly.
struct TerminalRevealText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var progress: TerminalRevealProgress

    private let intervalMilliseconds: UInt64
    private let showsCursor: Bool
    private let isSkippable: Bool

    init(_ text: String, intervalMilliseconds: UInt64 = 22, showsCursor: Bool = true, isSkippable: Bool = true) {
        _progress = State(initialValue: TerminalRevealProgress(finalText: text))
        self.intervalMilliseconds = intervalMilliseconds
        self.showsCursor = showsCursor
        self.isSkippable = isSkippable
    }

    init(localizedKey: String, intervalMilliseconds: UInt64 = 22, showsCursor: Bool = true, isSkippable: Bool = true) {
        self.init(String(localized: String.LocalizationValue(localizedKey)), intervalMilliseconds: intervalMilliseconds, showsCursor: showsCursor, isSkippable: isSkippable)
    }

    var body: some View {
        Text(displayText)
            .accessibilityLabel(Text(progress.finalText))
            .accessibilityValue(Text(progress.finalText))
            .onTapGesture {
                if isSkippable { progress.complete() }
            }
            .task(id: progress.finalText) {
                if reduceMotion || voiceOverEnabled {
                    progress.complete()
                    return
                }
                while !progress.isComplete && !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(intervalMilliseconds)) }
                    catch { return }
                    progress.advance()
                }
            }
    }

    private var displayText: String {
        if reduceMotion || voiceOverEnabled { return progress.finalText }
        return progress.visibleText + (showsCursor && !progress.isComplete ? "▌" : "")
    }
}
