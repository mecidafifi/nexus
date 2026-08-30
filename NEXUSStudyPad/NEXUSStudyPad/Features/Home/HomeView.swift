import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var lectures: [Lecture]
    @Query private var tasks: [StudyTask]
    @Query private var courses: [Course]
    @Query private var scheduleRules: [CourseScheduleRule]
    @Environment(\.modelContext) private var context
    @State private var mode: HomeMode = .today
    let openTransfer: () -> Void

    init(openTransfer: @escaping () -> Void = {}) {
        self.openTransfer = openTransfer
    }

    private var snapshot: HomeSnapshot {
        HomeViewModel.snapshot(now: .now, lectures: lectures, tasks: tasks, rules: scheduleRules, courses: courses)
    }

    var body: some View {
        ZStack {
            TerminalBackground(showGlobe: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(mode == .today ? "NEXUS // BUGÜN" : "NEXUS // HAFTA")
                            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        Text(Date.now.formatted(date: .complete, time: .omitted)).foregroundStyle(PadTokens.phosphorDim)
                    }
                    Picker("Görünüm", selection: $mode) {
                        ForEach(HomeMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("Bugün ve önümüzdeki yedi gün arasında geçiş yapar")
                    transferEntry
                    if mode == .today { todayContent }
                    else { weekContent }
                }.padding(24)
            }
        }.terminalPage().navigationTitle(mode.title)
    }

    private var todayContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                        TerminalCard("Bugünün ilerlemesi") {
                            TerminalProgressBar(completed: snapshot.completedTasks, total: snapshot.todayTasks.count)
                        }
                        TerminalCard("Bugünün dersleri") {
                            if snapshot.todayLessons.isEmpty { Text("Bugün için ders veya oturum yok.").foregroundStyle(PadTokens.phosphorDim) }
                            ForEach(snapshot.todayLessons) { lessonRow($0) }
                        }
                        TerminalCard("Bugünün görevleri") {
                            if snapshot.todayTasks.isEmpty { Text("Bugün için son tarihli görev yok.").foregroundStyle(PadTokens.phosphorDim) }
                            ForEach(snapshot.todayTasks) { task in
                                Button {
                                    task.isCompleted.toggle(); task.updatedAt = .now; try? context.save()
                                } label: {
                                    Label(task.title, systemImage: task.isCompleted ? "checkmark.square.fill" : "square")
                                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).frame(minHeight: PadTokens.minimumTap)
                                    .accessibilityLabel("\(task.title), \(task.isCompleted ? "tamamlandı" : "tamamlanmadı")")
                                    .accessibilityHint("Durumu değiştirir")
                            }
                        }
                        TerminalCard("Yaklaşan oturumlar") {
                            if snapshot.upcomingLessons.isEmpty { Text("Yaklaşan ders veya oturum yok.").foregroundStyle(PadTokens.phosphorDim) }
                            ForEach(snapshot.upcomingLessons) { lesson in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lesson.title).fontWeight(.semibold)
                                    Text("\(lesson.detail) • \(lesson.startDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(PadTokens.phosphorDim)
                                }.padding(.vertical, 3)
                                    .accessibilityElement(children: .combine)
                            }
                        }
        }
    }

    private var weekContent: some View {
        LazyVStack(spacing: 14) {
            ForEach(snapshot.weekDays) { day in
                TerminalCard(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                    if day.lessons.isEmpty && day.tasks.isEmpty {
                        Text("Planlanmış ders veya görev yok.").foregroundStyle(PadTokens.phosphorDim)
                    }
                    ForEach(day.lessons) { lessonRow($0) }
                    ForEach(day.tasks) { task in
                        Button { toggle(task) } label: {
                            Label(task.title, systemImage: task.isCompleted ? "checkmark.square.fill" : "square")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: PadTokens.minimumTap)
                        .accessibilityLabel("\(task.title), \(task.isCompleted ? "tamamlandı" : "tamamlanmadı")")
                        .accessibilityHint("Durumu değiştirir")
                    }
                }
            }
        }
    }

    private func lessonRow(_ lesson: HomeLessonItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(lesson.startDate, format: .dateTime.hour().minute()).fontWeight(.bold).monospacedDigit()
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title).fontWeight(.semibold)
                let metadata = [lesson.detail, lesson.location].filter { !$0.isEmpty }.joined(separator: " • ")
                if !metadata.isEmpty { Text(metadata).font(.caption).foregroundStyle(PadTokens.phosphorDim) }
            }
            Spacer()
            TerminalStatusBadge(text: lesson.status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lessonAccessibilityLabel(lesson))
    }

    private func lessonAccessibilityLabel(_ lesson: HomeLessonItem) -> String {
        let time = lesson.startDate.formatted(date: .omitted, time: .shortened)
        let end = lesson.endDate?.formatted(date: .omitted, time: .shortened)
        return [time, end, lesson.title, lesson.detail, lesson.location, lesson.status].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: ", ")
    }

    private func toggle(_ task: StudyTask) {
        task.isCompleted.toggle()
        task.updatedAt = .now
        try? context.save()
    }

    private var transferEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mac'ten verileri aktar", systemImage: "square.and.arrow.down.on.square.fill")
                .font(.system(.title2, design: .monospaced, weight: .bold))
            Text("NEXUS Mac yedeğinizi Files içinden seçin; veriler doğrulama ve önizlemeden sonra yalnız açık onayınızla içe aktarılır.")
                .foregroundStyle(PadTokens.phosphorDim)
            Button(action: openTransfer) {
                Label("NEXUS Mac yedeğini seç", systemImage: "doc.badge.plus")
                    .font(.system(.headline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PadTokens.background)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 56)
            .accessibilityIdentifier(TransferEntryAccessibility.buttonIdentifier)
            .accessibilityHint("Mac aktarım ekranını açar; henüz dosya seçmez veya veri yazmaz")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PadTokens.panelRaised.opacity(0.98))
        .overlay(RoundedRectangle(cornerRadius: PadTokens.cornerRadius).stroke(PadTokens.phosphor, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: PadTokens.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TransferEntryAccessibility.cardIdentifier)
    }
}

private enum HomeMode: String, CaseIterable, Identifiable {
    case today
    case week
    var id: String { rawValue }
    var title: String { self == .today ? String(localized: "Bugün") : String(localized: "Hafta") }
}

enum TransferEntryAccessibility {
    static let cardIdentifier = "today.transfer.card"
    static let buttonIdentifier = "today.transfer.open"
}
