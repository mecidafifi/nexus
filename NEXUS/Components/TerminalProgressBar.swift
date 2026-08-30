import SwiftUI

struct TerminalProgressBar: View {
    let value: Double
    var labelKey = "progress.label"
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(LocalizedStringKey(labelKey)); Spacer(); Text(value, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(TerminalTokens.surfaceRaised)
                    Rectangle().fill(TerminalTokens.phosphor).frame(width: geometry.size.width * min(max(value, 0), 1))
                }
            }.frame(height: 8)
        }
        .font(.system(.caption, design: .monospaced))
        .accessibilityValue(Text(value, format: .percent))
    }
}
