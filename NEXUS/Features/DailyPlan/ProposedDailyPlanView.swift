import SwiftUI
import SwiftData

struct ProposedDailyPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let fixed: [PlannerFixedItem]
    let candidates: [PlannerCandidate]
    let existingPlacements: [PlannedTaskPlacement]
    let settings: DailyPlannerSettings
    let onAccepted: (Int) -> Void
    @State private var proposal: ProposedDailyPlan
    @State private var selectedIDs: Set<String>
    @State private var editing = false
    @State private var error: String?

    init(date: Date, fixed: [PlannerFixedItem], candidates: [PlannerCandidate], existingPlacements: [PlannedTaskPlacement],
         settings: DailyPlannerSettings, onAccepted: @escaping (Int) -> Void) {
        self.date = date; self.fixed = fixed; self.candidates = candidates; self.existingPlacements = existingPlacements
        self.settings = settings; self.onAccepted = onAccepted
        let generated = ProposedDailyPlanner.generate(date: date, fixed: fixed, candidates: candidates, settings: settings)
        _proposal = State(initialValue: generated)
        _selectedIDs = State(initialValue: Set(generated.placements.map(\.id)))
    }

    var body: some View {
        TerminalWindow {
            TerminalDialog(titleKey: "planner.title") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("planner.proposedLabel").font(.headline).phosphorGlow()
                            Text(date, format: .dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(TerminalTokens.phosphorMuted)
                        }
                        Spacer()
                        Text(String(format: String(localized: "planner.selectedCount"), selectedPlacements.count, proposal.placements.count)).monospacedDigit()
                    }
                    Text("planner.transientHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                    if proposal.fixedConflictCount > 0 {
                        Label(String(format: String(localized: "planner.fixedConflicts"), proposal.fixedConflictCount), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(TerminalTokens.warning)
                    }
                    Divider().overlay(TerminalTokens.border)
                    if proposal.placements.isEmpty {
                        TerminalEmptyState(titleKey: "planner.empty.title", messageKey: "planner.empty.message")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(proposal.placements.indices, id: \.self) { index in placementRow(index) }
                                if !proposal.unplaced.isEmpty {
                                    Divider().overlay(TerminalTokens.border).padding(.vertical, 4)
                                    Text("planner.unplaced.title").font(.headline).foregroundStyle(TerminalTokens.warning)
                                    ForEach(proposal.unplaced) { item in
                                        HStack { Image(systemName: "exclamationmark.triangle"); Text(item.candidate.title); Spacer(); Text(LocalizedStringKey(item.reasonKey)).font(.caption) }
                                            .foregroundStyle(TerminalTokens.warning).padding(8).overlay(Rectangle().stroke(TerminalTokens.warning.opacity(0.55)))
                                    }
                                }
                            }
                        }
                    }
                    if let error { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error) }
                    HStack {
                        Button("planner.regenerate") { regenerate() }.buttonStyle(TerminalButtonStyle())
                        Button(editing ? "planner.finishEditing" : "planner.edit") { editing.toggle() }.buttonStyle(TerminalButtonStyle())
                        Spacer()
                        Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle())
                        Button("planner.accept") { accept() }.buttonStyle(TerminalPrimaryButtonStyle()).disabled(selectedPlacements.isEmpty)
                    }
                }
            }.padding()
        }
        .frame(width: 760, height: 720)
        .accessibilityIdentifier("planner.proposal.screen")
    }

    private func placementRow(_ index: Int) -> some View {
        let placement = proposal.placements[index]
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { selectedIDs.contains(placement.id) }, set: { selected in
                if selected { selectedIDs.insert(placement.id) } else { selectedIDs.remove(placement.id) }
            })).labelsHidden().accessibilityLabel(Text(String(format: String(localized: "planner.selectItem"), placement.candidate.title)))
            Image(systemName: sourceSymbol(placement.candidate.source)).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(placement.candidate.title).fontWeight(.semibold)
                Text(LocalizedStringKey("planner.source.\(placement.candidate.source.rawValue)"))
                    .font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }
            Spacer()
            if editing {
                DatePicker("", selection: startBinding(index), displayedComponents: .hourAndMinute).labelsHidden().frame(width: 105)
                Button { selectedIDs.remove(placement.id) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain).accessibilityLabel(Text("planner.remove"))
            } else {
                Text(placement.start, style: .time).monospacedDigit()
                Text("–")
                Text(placement.end, style: .time).monospacedDigit()
            }
        }.padding(10).background(selectedIDs.contains(placement.id) ? TerminalTokens.phosphor.opacity(0.1) : TerminalTokens.surface.opacity(0.35))
            .overlay(Rectangle().stroke(selectedIDs.contains(placement.id) ? TerminalTokens.phosphor : TerminalTokens.border))
    }

    private var selectedPlacements: [ProposedTaskPlacement] { proposal.placements.filter { selectedIDs.contains($0.id) } }

    private func startBinding(_ index: Int) -> Binding<Date> {
        Binding(get: { proposal.placements[index].start }, set: { value in
            let duration = proposal.placements[index].end.timeIntervalSince(proposal.placements[index].start)
            proposal.placements[index].start = value
            proposal.placements[index].end = value.addingTimeInterval(duration)
        })
    }

    private func regenerate() {
        proposal = ProposedDailyPlanner.generate(date: date, fixed: fixed, candidates: candidates, settings: settings)
        selectedIDs = Set(proposal.placements.map(\.id)); editing = false; error = nil
    }

    private func accept() {
        do {
            let chosen = selectedPlacements
            try PlannerAcceptanceService.accept(chosen, fixed: fixed, date: date, existing: existingPlacements, context: context)
            onAccepted(chosen.count)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func sourceSymbol(_ source: TaskPlacementSource) -> String {
        switch source { case .studyTask: "book.closed"; case .organizationTask: "square.grid.2x2"; case .calendarTask: "calendar" }
    }
}
