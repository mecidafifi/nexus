import SwiftUI
import SwiftData

struct QuickEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var rules: [StudyScheduleRule]
    @Query private var plannedWorkouts: [PlannedWorkoutSession]
    @Query private var studyTasks: [StudyTask]
    @Query private var calendarEntries: [CalendarEntry]
    @State private var input = ""
    @State private var draft: QuickEntryDraft?
    @State private var error: String?
    @State private var success: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        TerminalWindow {
            TerminalDialog(titleKey: "quickEntry.title") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("quickEntry.localOnly").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                    HStack {
                        TextField("quickEntry.placeholder", text: $input, axis: .vertical)
                            .textFieldStyle(.plain).lineLimit(2...4).focused($inputFocused)
                            .padding(10).background(TerminalTokens.surface).overlay(Rectangle().stroke(TerminalTokens.border))
                            .accessibilityIdentifier("quickEntry.input")
                        Button("quickEntry.parse") { parse() }.buttonStyle(TerminalPrimaryButtonStyle())
                    }
                    Text("quickEntry.supportedSyntax").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                    Divider().overlay(TerminalTokens.border)
                    if let draft { draftEditor(draft) }
                    else { TerminalEmptyState(titleKey: "quickEntry.empty.title", messageKey: "quickEntry.empty.message") }
                    if let error { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error).accessibilityIdentifier("quickEntry.error") }
                    if let success { Label(success, systemImage: "checkmark.circle").foregroundStyle(TerminalTokens.success) }
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle())
                        Button("quickEntry.confirm") { confirm() }.buttonStyle(TerminalPrimaryButtonStyle()).disabled(draft == nil)
                    }
                }
            }.padding()
        }
        .frame(width: 720, height: 680)
        .onAppear { inputFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in if draft != nil { confirm() } else { parse() } }
        .accessibilityIdentifier("quickEntry.screen")
    }

    @ViewBuilder
    private func draftEditor(_ value: QuickEntryDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("quickEntry.understood", systemImage: "checkmark.seal")
                Spacer()
                Text(LocalizedStringKey(value.kind.titleKey)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }.fontWeight(.semibold)
            Text("quickEntry.confirmationRequired").font(.caption).foregroundStyle(TerminalTokens.warning)
            TextField("quickEntry.field.title", text: draftBinding(\.title)).textFieldStyle(.roundedBorder)
            DatePicker("quickEntry.field.time", selection: timeBinding, displayedComponents: .hourAndMinute)
            Stepper(value: durationBinding, in: 10...180, step: 5) {
                LabeledContent("quickEntry.field.duration", value: String(format: String(localized: "format.minutes"), value.durationMinutes))
            }
            switch value.kind {
            case .weeklyLesson:
                Picker("quickEntry.field.weekday", selection: Binding(get: { draft?.weekday ?? 2 }, set: { draft?.weekday = $0 })) {
                    ForEach(1...7, id: \.self) { day in Text(weekdayName(day)).tag(day) }
                }
                DatePicker("quickEntry.field.start", selection: draftBinding(\.effectiveStart), displayedComponents: .date)
                DatePicker("quickEntry.field.until", selection: Binding(get: { draft?.effectiveEnd ?? .now }, set: { draft?.effectiveEnd = $0 }), displayedComponents: .date)
                previewLine("quickEntry.preview.recurrence", weekdayName(value.weekday ?? 2))
                previewLine("quickEntry.preview.until", value.effectiveEnd?.formatted(date: .abbreviated, time: .omitted) ?? "—")
            case .weeklyGym:
                Text("quickEntry.gym.proposedDates").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                ForEach(value.occurrenceDates.indices, id: \.self) { index in
                    HStack {
                        DatePicker("", selection: occurrenceBinding(index), displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                        Spacer()
                        Button { draft?.occurrenceDates.remove(at: index) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).accessibilityLabel(Text("quickEntry.removeOccurrence"))
                    }
                }
                Button("quickEntry.addOccurrence") { addGymOccurrence() }.buttonStyle(TerminalButtonStyle())
                Text("quickEntry.gym.reviewDates").font(.caption2).foregroundStyle(TerminalTokens.warning)
            case .studyTask, .calendarTask, .calendarEvent, .gymSession:
                DatePicker("quickEntry.field.date", selection: draftBinding(\.effectiveStart), displayedComponents: .date)
                previewLine("quickEntry.preview.destination", String(localized: String.LocalizationValue(value.kind.titleKey)))
                previewLine("quickEntry.preview.date", value.effectiveStart.formatted(date: .abbreviated, time: .shortened))
            }
        }.padding(12).background(TerminalTokens.surface.opacity(0.5)).overlay(Rectangle().stroke(TerminalTokens.border))
    }

    private func previewLine(_ key: String, _ value: String) -> some View {
        HStack { Text(LocalizedStringKey(key)).foregroundStyle(TerminalTokens.phosphorMuted); Spacer(); Text(value) }.font(.caption)
    }

    private func parse() {
        do { draft = try TurkishQuickEntryParser.parse(input); error = nil; success = nil }
        catch { draft = nil; self.error = error.localizedDescription; success = nil }
    }

    private func confirm() {
        guard let draft else { return }
        do {
            let count = try QuickEntryPersistenceService.confirm(
                draft, courses: courses, rules: rules, plannedWorkouts: plannedWorkouts,
                studyTasks: studyTasks, calendarEntries: calendarEntries, context: context
            )
            success = String(format: String(localized: "quickEntry.savedCount"), count)
            error = nil
            self.draft = nil
            input = ""
        } catch { self.error = error.localizedDescription; success = nil }
    }

    private func draftBinding<Value>(_ keyPath: WritableKeyPath<QuickEntryDraft, Value>) -> Binding<Value> {
        Binding(get: { draft![keyPath: keyPath] }, set: { draft?[keyPath: keyPath] = $0 })
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            let base = Calendar.current.startOfDay(for: draft?.effectiveStart ?? .now)
            return Calendar.current.date(byAdding: .minute, value: draft?.startMinutes ?? 540, to: base) ?? base
        }, set: { value in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
            draft?.startMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if draft?.kind == .weeklyGym {
                draft?.occurrenceDates = draft?.occurrenceDates.map { date in
                    Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: date) ?? date
                } ?? []
            } else if let current = draft?.effectiveStart {
                draft?.effectiveStart = Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: current) ?? current
                if let start = draft?.effectiveStart, let duration = draft?.durationMinutes {
                    draft?.effectiveEnd = Calendar.current.date(byAdding: .minute, value: duration, to: start)
                }
            }
        })
    }

    private var durationBinding: Binding<Int> {
        Binding(get: { draft?.durationMinutes ?? 60 }, set: { value in
            draft?.durationMinutes = value
            if let kind = draft?.kind, ![QuickEntryDraftKind.weeklyLesson, .weeklyGym].contains(kind),
               let start = draft?.effectiveStart {
                draft?.effectiveEnd = Calendar.current.date(byAdding: .minute, value: value, to: start)
            }
        })
    }

    private func occurrenceBinding(_ index: Int) -> Binding<Date> {
        Binding(get: { draft!.occurrenceDates[index] }, set: { draft?.occurrenceDates[index] = $0 })
    }

    private func addGymOccurrence() {
        guard let last = draft?.occurrenceDates.last,
              let next = Calendar.current.date(byAdding: .day, value: 1, to: last) else { return }
        draft?.occurrenceDates.append(next)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let names = Calendar.current.weekdaySymbols
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : "\(weekday)"
    }
}
