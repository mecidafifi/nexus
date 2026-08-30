import SwiftUI
import SwiftData

struct DailyPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @StateObject private var prerequisiteCourseViewModel = StudyViewModel()
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \StudyScheduleRule.startMinutes) private var rules: [StudyScheduleRule]
    @Query private var attendance: [AttendanceRecord]
    @Query private var studyTasks: [StudyTask]
    @Query private var studySessions: [StudySession]
    @Query private var plannedWorkouts: [PlannedWorkoutSession]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var completedWorkouts: [WorkoutRecord]
    @Query private var calendarEntries: [CalendarEntry]
    @Query private var assessments: [OBSAssessment]
    @Query private var universityCourses: [UniversityCourse]
    @Query private var debts: [DebtRecord]
    @Query private var recurringTransactions: [RecurringTransaction]
    @Query private var notes: [NexusNote]
    @Query private var organizationProjects: [ProjectRecord]
    @Query private var organizationTasks: [OrganizationTask]
    @Query private var taskPlacements: [PlannedTaskPlacement]
    @Query private var focusSessions: [FocusSessionRecord]

    @AppStorage("planner.workStartMinutes") private var plannerWorkStart = 480
    @AppStorage("planner.workEndMinutes") private var plannerWorkEnd = 1200
    @AppStorage("planner.bufferMinutes") private var plannerBuffer = 10
    @AppStorage("planner.defaultDurationMinutes") private var plannerDefaultDuration = 45
    @AppStorage("eveningReview.endMinutes") private var eveningReviewEndMinutes = 1_200
    @AppStorage("eveningReview.lastAcknowledgedDay") private var lastEveningReviewDay = ""

    @State private var mode: DailyPlanMode = DailyPlanPresentationPolicy.defaultMode
    @State private var selectedDate = DailyPlanPresentationPolicy.defaultSelectedDate()
    @State private var didPrepareInitialPresentation = false
    @State private var selectedItemID: String?
    @State private var query = ""
    @State private var editorRuleID: UUID?
    @State private var creatingRule = false
    @State private var creatingPrerequisiteCourse = false
    @State private var prerequisiteCourseSaved = false
    @State private var deletingRule: StudyScheduleRule?
    @State private var showEndOfDayReview = false
    @State private var showProposedPlan = false
    @State private var ignoredConflictDay: Date?
    @State private var statusKey = "dailyPlan.status.ready"
    @State private var statusKind: TerminalStatusKind = .neutral
    @FocusState private var searchFocused: Bool
    @FocusState private var planFocused: Bool
    @FocusState private var focusedTaskID: String?

    private var snapshot: DailyPlanSnapshot { makeSnapshot(for: selectedDate) }
    private var visibleItems: [DailyPlanItem] {
        let all = snapshot.items + snapshot.freeBlocks
        let filtered = query.isEmpty ? all : all.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
        return filtered.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
    private var timelineItems: [DailyPlanItem] {
        let items = DailyPlanTimelinePolicy.timedItems(from: snapshot)
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
    }
    private var selectableItems: [DailyPlanItem] { visibleItems.filter { $0.kind != .freeTime } }
    private var selectedDayTasks: [DailyPlanItem] {
        let items = DailyPlanTimelinePolicy.selectedDayTasks(from: snapshot)
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
    }
    private var dayTaskProgress: DailyPlanTaskProgress { DailyPlanTaskProgressPolicy.progress(from: snapshot.items) }
    private var selectedItem: DailyPlanItem? { snapshot.items.first { $0.id == selectedItemID } }
    private var selectedLesson: DailyPlanItem? {
        selectedItem.flatMap { $0.kind == .lesson ? $0 : nil }
    }
    private var overdueCount: Int { OverdueReviewService.items(studyTasks: studyTasks, organizationTasks: organizationTasks).count }
    private var eveningReviewSuggested: Bool {
        Calendar.current.isDateInToday(selectedDate) && EveningReviewAcknowledgement.shouldSuggest(
            lastAcknowledgedDay: lastEveningReviewDay, now: .now, endMinutes: eveningReviewEndMinutes
        )
    }
    private var conflictCount: Int {
        let timed = snapshot.items.filter { $0.kind != .freeTime && $0.start != nil && $0.end != nil }
        var count = 0
        for left in timed.indices {
            for right in timed.indices where right > left {
                if let leftStart = timed[left].start, let leftEnd = timed[left].end,
                   let rightStart = timed[right].start, let rightEnd = timed[right].end,
                   leftStart < rightEnd, rightStart < leftEnd { count += 1 }
            }
        }
        return count
    }
    private var eveningReviewLabel: String {
        let base = String(localized: "evening.action")
        if eveningReviewSuggested { return "\(base) • \(String(localized: "evening.recommended"))" }
        return overdueCount == 0 ? base : "\(base) (\(overdueCount))"
    }
    private var conflictsIgnored: Bool { ignoredConflictDay.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } ?? false }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch mode {
            case .today: todayView
            case .week: weekView
            case .month: monthView
            }
            TerminalStatusBar(messageKey: statusKey, kind: statusKind)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable().focused($planFocused)
        .onAppear {
            guard !didPrepareInitialPresentation else { return }
            didPrepareInitialPresentation = true
            selectedDate = DailyPlanPresentationPolicy.defaultSelectedDate()
            mode = appState.consumeDailyPlanLaunchDefault() ?? DailyPlanPresentationPolicy.defaultMode
            selectedItemID = nil
        }
        .onMoveCommand(perform: moveSelection)
        .onKeyPress(.return) {
            if let focusedTaskID, let item = selectedDayTasks.first(where: { $0.id == focusedTaskID }) {
                toggleTask(item)
            } else {
                openSelection()
            }
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in newSchedule() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .nexusEveningReview)) { _ in showEndOfDayReview = true }
        .sheet(isPresented: $creatingRule) { DailyPlanRuleEditor(rule: nil, courses: courses, selectedDate: selectedDate) }
        .sheet(isPresented: $creatingPrerequisiteCourse, onDismiss: continueAfterPrerequisiteCourse) {
            CourseEditorView(
                course: nil,
                viewModel: prerequisiteCourseViewModel,
                contextMessageKey: "dailyPlan.coursePrerequisite.message",
                onSaved: { prerequisiteCourseSaved = true }
            )
        }
        .sheet(item: $editorRuleID) { id in DailyPlanRuleEditor(rule: rules.first { $0.id == id }, courses: courses, selectedDate: selectedDate) }
        .sheet(isPresented: $showEndOfDayReview) { EndOfDayReviewView(date: selectedDate) }
        .sheet(isPresented: $showProposedPlan) {
            ProposedDailyPlanView(date: selectedDate, fixed: plannerFixedItems, candidates: plannerCandidates,
                                  existingPlacements: taskPlacements, settings: plannerSettings) { _ in
                statusKey = "planner.status.accepted"; statusKind = .success
            }
        }
        .confirmationDialog("dailyPlan.deleteSchedule.title", isPresented: Binding(get: { deletingRule != nil }, set: { if !$0 { deletingRule = nil } })) {
            Button("dailyPlan.deleteSchedule.action", role: .destructive) { deleteSchedule() }
            Button("action.cancel", role: .cancel) { deletingRule = nil }
        } message: { Text("dailyPlan.deleteSchedule.message") }
        .accessibilityIdentifier("home.screen")
        .accessibilityHint(Text("dailyPlan.keyboardHint"))
    }

    private var header: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    dashboardTitle
                    Spacer(minLength: 12)
                    dayProgressHeader.frame(width: 270)
                    modePicker.frame(width: 250)
                    dateNavigation
                }
                VStack(alignment: .leading, spacing: 10) {
                    dashboardTitle
                    dayProgressHeader
                    HStack(spacing: 8) {
                        modePicker.frame(maxWidth: 300)
                        Spacer(minLength: 4)
                        dateNavigation
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(TerminalTokens.surface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                        TextField("dailyPlan.search", text: $query)
                            .textFieldStyle(.plain).focused($searchFocused).frame(width: 205)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(TerminalTokens.background.opacity(0.55))
                    .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.7)))
                    Button { showEndOfDayReview = true } label: {
                        Label(eveningReviewLabel, systemImage: eveningReviewSuggested ? "sunset.fill" : "sunset")
                    }.buttonStyle(TerminalButtonStyle())
                        .foregroundStyle(eveningReviewSuggested ? TerminalTokens.warning : TerminalTokens.phosphor)
                        .accessibilityHint(Text("evening.open.hint"))
                    Button { appState.openMorningBriefing() } label: { Label("briefing.short", systemImage: "sunrise") }.buttonStyle(TerminalButtonStyle())
                    Button { showProposedPlan = true } label: { Label("planner.open", systemImage: "wand.and.stars") }.buttonStyle(TerminalButtonStyle())
                    Button { appState.openQuickEntry() } label: { Label("quickEntry.short", systemImage: "text.badge.plus") }.buttonStyle(TerminalButtonStyle())
                    Button { appState.openControlSystem() } label: { Label("dailyPlan.nexusMenu", systemImage: "command") }
                        .buttonStyle(TerminalButtonStyle()).accessibilityIdentifier("dailyPlan.nexusMenu")
                    Button(action: newSchedule) { Label("dailyPlan.newLesson", systemImage: "plus") }
                        .buttonStyle(TerminalPrimaryButtonStyle())
                        .accessibilityIdentifier("dailyPlan.new")
                        .accessibilityHint(Text("dailyPlan.newLesson.hint"))
                }.padding(.horizontal, 16).padding(.vertical, 7)
            }.background(TerminalTokens.surface.opacity(0.45))
            if conflictCount > 0 && !conflictsIgnored {
                HStack(spacing: 10) {
                    Label(String(format: String(localized: "conflict.count"), conflictCount), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(TerminalTokens.warning)
                    Spacer()
                    Button("conflict.findTime") { appState.openSemesterSetup() }.buttonStyle(TerminalButtonStyle())
                    Button("conflict.keep") { ignoredConflictDay = selectedDate }.buttonStyle(TerminalButtonStyle())
                }.padding(.horizontal, 16).frame(height: 42).background(TerminalTokens.warning.opacity(0.08))
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private var dashboardTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            TerminalRevealText(localizedKey: "dailyPlan.systemTitle", intervalMilliseconds: 18)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .phosphorGlow()
            Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .foregroundStyle(TerminalTokens.phosphorMuted)
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var modePicker: some View {
        Picker("dailyPlan.view", selection: $mode) {
            ForEach(DailyPlanMode.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
        }.pickerStyle(.segmented)
    }

    private var dayProgressHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("dailyPlan.dayProgress.title").fontWeight(.semibold)
                Spacer(minLength: 4)
                Text(dayTaskProgress.countText).fontWeight(.bold).monospacedDigit()
                Text(dayTaskProgress.percentageText).foregroundStyle(TerminalTokens.phosphorMuted).monospacedDigit()
            }
            Text(dayTaskProgress.asciiBar(width: 24))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.72)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(TerminalTokens.background.opacity(0.62))
        .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.86)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(String(localized: "dailyPlan.dayProgress.title")), \(dayTaskProgress.countText), \(dayTaskProgress.percentageText)"))
        .accessibilityIdentifier("dailyPlan.taskProgress")
    }

    private var dateNavigation: some View {
        HStack(spacing: 6) {
            Button { shiftDate(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("dailyPlan.previous"))
            Button("dailyPlan.today") { selectDate(.now, switchToToday: true) }.buttonStyle(TerminalButtonStyle())
            Button { shiftDate(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("dailyPlan.next"))
        }.fixedSize()
    }

    private var todayView: some View {
        GeometryReader { geometry in
            switch DailyPlanDashboardLayoutPolicy.widthClass(for: geometry.size.width) {
            case .wide:
                HStack(spacing: 7) {
                    verticalWeekRail.frame(width: 154)
                    timelinePanel.frame(minWidth: 500, maxWidth: .infinity)
                    inspector.frame(width: 326)
                }.padding(8)
            case .medium:
                VStack(spacing: 8) {
                    horizontalWeekRail
                    HStack(spacing: 8) {
                        timelinePanel.frame(minWidth: 430, maxWidth: .infinity)
                        inspector.frame(width: 285)
                    }
                }.padding(10)
            case .compact:
                ScrollView {
                    VStack(spacing: 10) {
                        horizontalWeekRail
                        timelinePanel.frame(height: 650)
                        inspector.frame(minHeight: 420)
                    }.padding(10)
                }
            }
        }.accessibilityIdentifier("dailyplan.today")
    }

    private var verticalWeekRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(weekOfTitle).font(.system(.caption, design: .monospaced, weight: .semibold)).foregroundStyle(TerminalTokens.phosphorMuted)
            ForEach(DailyPlanAggregator.weekDates(containing: selectedDate), id: \.self) { date in
                weekRailButton(date: date, horizontal: false)
            }
            Spacer()
            Label("dailyPlan.organizationActive", systemImage: "square.grid.2x2").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).fixedSize(horizontal: false, vertical: true)
        }.padding(10).dashboardPanel()
    }

    private var horizontalWeekRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekOfTitle).font(.system(.caption, design: .monospaced, weight: .semibold)).foregroundStyle(TerminalTokens.phosphorMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(DailyPlanAggregator.weekDates(containing: selectedDate), id: \.self) { date in
                        weekRailButton(date: date, horizontal: true).frame(width: 126)
                    }
                }
            }
        }.padding(10).dashboardPanel()
    }

    private func weekRailButton(date: Date, horizontal: Bool) -> some View {
        let day = makeSnapshot(for: date)
        let progress = DailyPlanTaskProgressPolicy.progress(from: day.items)
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let today = Calendar.current.isDateInToday(date)
        return Button { selectDate(date, switchToToday: true) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: selected ? "chevron.right" : (today ? "circle.fill" : "circle"))
                        .font(.system(size: selected ? 10 : 6, weight: .bold))
                    Text(date, format: .dateTime.weekday(.abbreviated)).fontWeight(.semibold)
                    Spacer(minLength: 2)
                    Text(date, format: .dateTime.day()).monospacedDigit()
                }
                HStack(spacing: 5) {
                    Text(progress.total > 0 && progress.completed == progress.total ? "[x]" : "[ ]")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                    Text(progress.countText)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }.font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                if !horizontal {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(TerminalTokens.surfaceRaised)
                            Rectangle().fill(TerminalTokens.phosphor).frame(width: geometry.size.width * progress.fraction)
                        }
                    }.frame(height: 4).accessibilityHidden(true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(horizontal ? 8 : 8)
                .background(selected ? TerminalTokens.phosphor.opacity(0.13) : TerminalTokens.background.opacity(0.38))
                .overlay(Rectangle().stroke(selected ? TerminalTokens.phosphor : TerminalTokens.border.opacity(0.55), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(date.formatted(.dateTime.weekday(.wide).day().month())), \(progress.countText)"))
        .accessibilityHint(Text("dailyPlan.rail.openDay"))
    }

    private var weekOfTitle: String {
        let dates = DailyPlanAggregator.weekDates(containing: selectedDate)
        guard let first = dates.first, let last = dates.last else { return String(localized: "dailyPlan.weekStrip") }
        let range = "\(first.formatted(.dateTime.day().month(.abbreviated)))–\(last.formatted(.dateTime.day().month(.abbreviated)))"
        return String(format: String(localized: "dailyPlan.weekOf"), range)
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("dailyPlan.timeline", systemImage: "clock").font(.headline)
                Spacer()
                Text(String(format: String(localized: "dailyPlan.scheduledCount"), timelineItems.filter { $0.kind != .freeTime }.count))
                    .font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }
            if !DailyPlanTimelinePolicy.hasScheduledContent(timelineItems) {
                Label("dailyPlan.timeline.empty", systemImage: "clock.badge.questionmark")
                    .font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                    .accessibilityIdentifier("dailyPlan.timeline.empty")
            }
            timeGrid
        }.padding(11).dashboardPanel()
    }

    private var timeGrid: some View {
        let bounds = DailyPlanTimelinePolicy.bounds(for: timelineItems, on: selectedDate)
        let pointsPerHour: CGFloat = 24
        let height = CGFloat(bounds.durationMinutes) / 60 * pointsPerHour
        let lanes = DailyPlanTimelinePolicy.lanes(for: timelineItems)
        let laneMap = Dictionary(uniqueKeysWithValues: lanes.map { ($0.itemID, $0.lane) })
        let laneCount = max((lanes.map(\.lane).max() ?? 0) + 1, 1)
        return ScrollView(.vertical) {
            GeometryReader { geometry in
                let axisWidth: CGFloat = 50
                let contentWidth = max(geometry.size.width - axisWidth - 4, 120)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stride(from: bounds.startMinutes, through: bounds.endMinutes, by: 60)), id: \.self) { minute in
                        let isMajorTick = minute % 120 == 0
                        HStack(spacing: 8) {
                            Text(isMajorTick ? clockLabel(minutes: minute) : "").font(.system(size: 10, design: .monospaced)).monospacedDigit()
                                .foregroundStyle(TerminalTokens.phosphorMuted).frame(width: 40, alignment: .trailing)
                            Rectangle().fill(TerminalTokens.border.opacity(isMajorTick ? 0.72 : 0.38)).frame(height: isMajorTick ? 1.2 : 0.7)
                        }.offset(y: CGFloat(minute - bounds.startMinutes) / 60 * pointsPerHour)
                            .allowsHitTesting(false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(clockLabel(minutes: minute)))
                    }
                    ForEach(timelineItems.filter { $0.kind == .freeTime }) { item in
                        timelineFreeBlock(item, bounds: bounds, width: contentWidth, pointsPerHour: pointsPerHour)
                            .offset(x: axisWidth)
                    }
                    ForEach(timelineItems.filter { $0.kind != .freeTime }) { item in
                        let lane = laneMap[item.id] ?? 0
                        let width = max((contentWidth - CGFloat(laneCount - 1) * 5) / CGFloat(laneCount), 90)
                        timelineEventBlock(item, bounds: bounds, width: width, pointsPerHour: pointsPerHour)
                            .offset(x: axisWidth + CGFloat(lane) * (width + 5))
                    }
                }.frame(width: geometry.size.width, height: height, alignment: .topLeading)
            }.frame(height: height)
        }
        .background(TerminalTokens.background.opacity(0.28))
        .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.82), lineWidth: 1))
        .accessibilityLabel(Text("dailyPlan.timeline.fullDay"))
        .accessibilityIdentifier("dailyPlan.timeline.grid")
    }

    private func timelineFreeBlock(_ item: DailyPlanItem, bounds: DailyPlanTimelineBounds, width: CGFloat, pointsPerHour: CGFloat) -> some View {
        let frame = timelineFrame(item, bounds: bounds, pointsPerHour: pointsPerHour)
        return HStack(spacing: 6) {
            Image(systemName: "pause")
            Text(item.title).font(.caption)
            Spacer()
            if let start = item.start, let end = item.end {
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))").font(.caption2).monospacedDigit()
            }
        }
        .foregroundStyle(TerminalTokens.phosphorMuted)
        .padding(.horizontal, 8).frame(width: width, height: max(frame.height - 4, 26), alignment: .leading)
        .background(TerminalTokens.surface.opacity(0.12))
        .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.48), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .offset(y: frame.y + 2).allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func timelineEventBlock(_ item: DailyPlanItem, bounds: DailyPlanTimelineBounds, width: CGFloat, pointsPerHour: CGFloat) -> some View {
        let frame = timelineFrame(item, bounds: bounds, pointsPerHour: pointsPerHour)
        let selected = selectedItemID == item.id
        let isPoint = DailyPlanTimelinePolicy.isPointInTime(item)
        return Button { selectedItemID = item.id; planFocused = true } label: {
            HStack(alignment: .top, spacing: 7) {
                Rectangle().fill(item.isCompleted ? TerminalTokens.success : TerminalTokens.phosphor).frame(width: 3)
                Image(systemName: symbol(item)).frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(item.title).fontWeight(item.isImportant ? .bold : .medium).lineLimit(1)
                        if item.kind == .lesson, ScheduleRulePresentationPolicy.isProvisionalDisplayText(item.subtitle) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(TerminalTokens.warning)
                                .accessibilityLabel(Text("schedule.provisional.badge"))
                        }
                        if item.isCompleted { Image(systemName: "checkmark.circle.fill").font(.caption) }
                    }
                    if frame.height >= 48, !item.subtitle.isEmpty {
                        Text(item.subtitle).font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(1)
                    }
                    if isPoint, let start = item.start {
                        Text("\(start.formatted(date: .omitted, time: .shortened)) · \(String(localized: "dailyPlan.durationUnspecified"))")
                            .font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(1)
                    } else if frame.height >= 54, let start = item.start, let end = item.end {
                        Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened)) · \(String(localized: String.LocalizationValue(item.source.route.titleKey)))")
                            .font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7).padding(.vertical, 6)
            .frame(width: width, height: isPoint ? 32 : max(frame.height - 4, 22), alignment: .topLeading)
            .background(selected ? TerminalTokens.phosphor.opacity(0.16) : TerminalTokens.surfaceRaised.opacity(0.88))
            .overlay(Rectangle().stroke(selected ? TerminalTokens.phosphor : TerminalTokens.border.opacity(0.95), lineWidth: selected ? 2.2 : 1.35))
        }
        .buttonStyle(.plain).offset(y: frame.y + 2)
        .contextMenu { contextMenu(for: item) }
        .accessibilityLabel(Text(itemAccessibilityLabel(item)))
        .accessibilityHint(Text("dailyPlan.timeline.selectHint"))
        .accessibilityIdentifier("dailyPlan.timeline.item.\(item.id)")
    }

    private func timelineFrame(_ item: DailyPlanItem, bounds: DailyPlanTimelineBounds, pointsPerHour: CGFloat) -> (y: CGFloat, height: CGFloat) {
        let day = Calendar.current.startOfDay(for: selectedDate)
        let start = item.start.map { Int($0.timeIntervalSince(day) / 60) } ?? bounds.startMinutes
        let end = item.end.map { Int(ceil($0.timeIntervalSince(day) / 60)) } ?? start
        let clippedStart = min(max(start, bounds.startMinutes), bounds.endMinutes)
        let clippedEnd = min(max(end, clippedStart), bounds.endMinutes)
        return (CGFloat(clippedStart - bounds.startMinutes) / 60 * pointsPerHour,
                CGFloat(clippedEnd - clippedStart) / 60 * pointsPerHour)
    }

    private func clockLabel(minutes: Int) -> String {
        if minutes == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    @ViewBuilder private func contextMenu(for item: DailyPlanItem) -> some View {
        if item.kind == .lesson, let occurrence = snapshot.lessons.first(where: { $0.id == item.id }) {
            Button("dailyPlan.attendance.attended") { mark(occurrence, .present) }
            Button("attendance.status.absent") { mark(occurrence, .absent) }
            Button("attendance.status.cancelled") { mark(occurrence, .cancelled) }
            Button("attendance.status.online") { mark(occurrence, .online) }
            Divider()
            Button("dailyPlan.editSchedule") { editorRuleID = occurrence.ruleID }
            Button("dailyPlan.deleteSchedule.action", role: .destructive) { deletingRule = rules.first { $0.id == occurrence.ruleID } }
        }
        if let request = focusRequest(for: item) {
            Button("focus.start") { appState.startFocus(request) }
            Divider()
        }
        Button("dailyPlan.openModule") { appState.open(item.source.route) }
    }

    private var inspector: some View {
        VStack(spacing: 7) {
            taskChecklistPanel.frame(minHeight: 230, maxHeight: .infinity)
            attendanceStatusPanel
            selectedItemPanel
        }
    }

    private var taskChecklistPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("dailyPlan.tasks.title").font(.system(.caption, design: .monospaced, weight: .bold))
                Spacer()
                Text(dayTaskProgress.countText).font(.system(.caption, design: .monospaced, weight: .bold)).monospacedDigit()
            }
            Divider().overlay(TerminalTokens.border.opacity(0.8))
            if selectedDayTasks.isEmpty {
                Text("dailyPlan.tasks.empty").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                Spacer(minLength: 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(selectedDayTasks) { item in taskToggleRow(item) }
                    }
                }
            }
            Text("dailyPlan.tasks.ratioScope")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(TerminalTokens.phosphorMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardPanel()
        .accessibilityIdentifier("dailyPlan.tasks.panel")
    }

    private func taskToggleRow(_ item: DailyPlanItem) -> some View {
        Button { toggleTask(item) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(item.isCompleted ? "[x]" : "[ ]")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                    .foregroundStyle(item.isCompleted ? TerminalTokens.success : TerminalTokens.phosphor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .strikethrough(item.isCompleted).lineLimit(1)
                    if let start = item.start {
                        Text(start, style: .time).font(.system(size: 9, design: .monospaced)).monospacedDigit()
                            .foregroundStyle(TerminalTokens.phosphorMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(item.isCompleted ? TerminalTokens.success.opacity(0.07) : TerminalTokens.background.opacity(0.30))
            .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.58)))
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedTaskID, equals: item.id)
        .onKeyPress(.space) { toggleTask(item); return .handled }
        .accessibilityLabel(Text("\(item.title), \(item.isCompleted ? String(localized: "task.status.completed") : String(localized: "task.status.planned"))"))
        .accessibilityHint(Text("dailyPlan.task.toggleHint"))
        .accessibilityValue(Text(item.isCompleted ? "[x]" : "[ ]"))
        .accessibilityIdentifier("dailyPlan.task.toggle.\(item.recordID?.uuidString.lowercased() ?? item.id)")
    }

    private var attendanceStatusPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("dailyPlan.attendance.statusTitle").font(.system(.caption, design: .monospaced, weight: .bold))
            Divider().overlay(TerminalTokens.border.opacity(0.8))
            if let item = selectedLesson, let occurrence = snapshot.lessons.first(where: { $0.id == item.id }) {
                HStack(spacing: 6) {
                    Image(systemName: attendanceStatus(for: occurrence)?.symbol ?? "questionmark.circle")
                    Text(attendanceStatus(for: occurrence).map { String(localized: String.LocalizationValue($0.titleKey)) } ?? String(localized: "dailyPlan.attendance.unmarked"))
                    Spacer()
                    Text(occurrence.start, style: .time).monospacedDigit()
                }.font(.caption).accessibilityLabel(Text("dailyPlan.attendance.current"))
                Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                    GridRow {
                        attendanceButton(.present, occurrence: occurrence)
                        attendanceButton(.absent, occurrence: occurrence)
                    }
                    GridRow {
                        attendanceButton(.cancelled, occurrence: occurrence)
                        attendanceButton(.online, occurrence: occurrence)
                    }
                }
                Text("dailyPlan.attendance.singleOccurrenceHelp").font(.system(size: 9, design: .monospaced)).foregroundStyle(TerminalTokens.phosphorMuted)
            } else {
                Text("dailyPlan.attendance.selectLesson").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).dashboardPanel()
    }

    private func attendanceButton(_ status: AttendanceStatus, occurrence: LessonOccurrence) -> some View {
        Button { mark(occurrence, status) } label: {
            Label(LocalizedStringKey(status.titleKey), systemImage: status.symbol)
                .font(.system(size: 10, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(TerminalButtonStyle()).accessibilityIdentifier("dailyPlan.attendance.\(status.rawValue)")
    }

    private var selectedItemPanel: some View {
        let inspectable = selectedItem.flatMap { $0.kind == .lesson || $0.kind == .gym ? $0 : nil }
        return VStack(alignment: .leading, spacing: 7) {
            Text(inspectable?.kind == .gym ? "dailyPlan.selectedWorkout" : "dailyPlan.selectedLesson")
                .font(.system(.caption, design: .monospaced, weight: .bold))
            Divider().overlay(TerminalTokens.border.opacity(0.8))
            if let item = inspectable {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: symbol(item))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.caption).fontWeight(.semibold).lineLimit(2)
                        if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(2) }
                    }
                }
                HStack {
                    Text(LocalizedStringKey(item.source.route.titleKey)).font(.caption2)
                    Spacer()
                    if let start = item.start, let end = item.end {
                        Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).monospacedDigit()
                    } else if let start = item.start {
                        Text("\(start.formatted(date: .omitted, time: .shortened)) · \(String(localized: "dailyPlan.durationUnspecified"))")
                            .font(.caption2).monospacedDigit()
                    }
                }.foregroundStyle(TerminalTokens.phosphorMuted)
                Button { appState.open(item.source.route) } label: { Label("dailyPlan.openModule", systemImage: "arrow.up.right.square") }
                    .buttonStyle(TerminalButtonStyle())
                    .accessibilityLabel(Text("\(String(localized: "dailyPlan.openModule")): \(item.title)"))
            } else {
                Text("dailyPlan.inspector.help").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).dashboardPanel()
    }

    private var weekView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DailyPlanPresentationPolicy.rollingRangeTitle(starting: selectedDate))
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(TerminalTokens.phosphorMuted)
                .padding(.horizontal, 14).padding(.top, 11)
                .accessibilityIdentifier("dailyplan.week.range")
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(DailyPlanPresentationPolicy.upcomingDates(starting: selectedDate), id: \.self) { date in
                        let day = makeSnapshot(for: date)
                        let datedItems = DailyPlanDatedPresentationPolicy.items(day.items)
                        let taskProgress = DailyPlanTaskProgressPolicy.progress(from: day.items)
                        VStack(alignment: .leading, spacing: 8) {
                            Button { selectDate(date, switchToToday: true) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(date, format: .dateTime.weekday(.wide)).fontWeight(.bold)
                                        Spacer()
                                        if Calendar.current.isDateInToday(date) { Image(systemName: "circle.fill").font(.system(size: 6)) }
                                    }
                                    Text(date, format: .dateTime.day().month(.abbreviated)).font(.caption)
                                    Text(taskProgress.countText)
                                        .font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).accessibilityHint(Text("dailyPlan.rail.openDay"))
                            TerminalProgressBar(value: taskProgress.fraction, labelKey: "dailyPlan.dayProgress.title")
                            if datedItems.isEmpty { Text("dailyPlan.dayEmpty").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }
                            ForEach(datedItems) { item in
                                weekItemButton(item, date: date)
                            }
                        }.frame(width: 184).padding(10).dashboardPanel()
                    }
                }.padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("dailyplan.week")
    }

    private func weekItemButton(_ item: DailyPlanItem, date: Date) -> some View {
        let displayedTime = item.start?.formatted(date: .omitted, time: .shortened) ?? "—"
        let isProvisionalLesson = item.kind == .lesson
            && ScheduleRulePresentationPolicy.isProvisionalDisplayText(item.subtitle)

        return Button {
            selectedDate = date
            selectedItemID = item.id
            mode = .today
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: symbol(item)).frame(width: 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayedTime).font(.caption).monospacedDigit()
                    Text(item.title)
                        .fontWeight(item.kind == .gym ? .semibold : .regular)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    if isProvisionalLesson {
                        Label("schedule.provisional.badge", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(TerminalTokens.warning)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(7)
            .background(TerminalTokens.surface)
            .overlay(Rectangle().stroke(TerminalTokens.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(itemAccessibilityLabel(item)))
        .accessibilityHint(Text("dailyPlan.timeline.selectHint"))
    }

    private var monthView: some View {
        HStack(spacing: 0) {
            let dates = DailyPlanAggregator.monthDates(containing: selectedDate)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(dates, id: \.self) { date in
                    let day = makeSnapshot(for: date)
                    monthDayCell(date: date, day: day)
                }
            }.padding(14).frame(maxWidth: .infinity)
            Divider().overlay(TerminalTokens.border)
            VStack(alignment: .leading, spacing: 8) {
                Text("dailyPlan.importantTasks").font(.headline)
                let important = dates.flatMap { DailyPlanDatedPresentationPolicy.items(makeSnapshot(for: $0).items) }.filter(\.isImportant)
                if important.isEmpty { Text("dailyPlan.noImportantTasks").foregroundStyle(TerminalTokens.phosphorMuted) }
                else { ScrollView { LazyVStack(alignment: .leading, spacing: 7) { ForEach(important.prefix(24)) { item in Button { if let date = item.start { selectedDate = date }; selectedItemID = item.id; mode = .today } label: { Label(item.title, systemImage: symbol(item)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(6).background(TerminalTokens.surface) } } } }
                Spacer()
            }.padding(14).frame(width: 280)
        }.accessibilityIdentifier("dailyplan.month")
    }

    private func monthDayCell(date: Date, day: DailyPlanSnapshot) -> some View {
        let gymItems = day.items.filter { $0.kind == .gym && $0.id.hasPrefix("planned-workout:") }
        let inSelectedMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return VStack(alignment: .leading, spacing: 4) {
            Button { selectDate(date, switchToToday: true) } label: {
                HStack(alignment: .top, spacing: 5) {
                    Text(date, format: .dateTime.day()).fontWeight(isSelected ? .bold : .regular)
                    Spacer(minLength: 2)
                    Text("\(day.items.count)").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                    if day.items.contains(where: \.isImportant) {
                        Label("dailyPlan.important", systemImage: "exclamationmark").font(.caption2).foregroundStyle(TerminalTokens.warning)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(date.formatted(.dateTime.weekday(.wide).day().month())))
            ForEach(Array(gymItems.prefix(2))) { item in
                monthGymCard(date: date, item: item)
            }
            if gymItems.count > 2 {
                Text("+\(gymItems.count - 2)").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
            }
            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading).padding(7)
        .background(inSelectedMonth ? TerminalTokens.surface : TerminalTokens.surface.opacity(0.25))
        .overlay(Rectangle().stroke(isSelected ? TerminalTokens.phosphor : TerminalTokens.border.opacity(0.55)))
    }

    private func monthGymCard(date: Date, item: DailyPlanItem) -> some View {
        Button {
            selectedDate = date
            selectedItemID = item.id
            mode = .today
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 8))
                Text(shortTime(item)).monospacedDigit()
                Text(item.title).lineLimit(1).truncationMode(.tail)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.vertical, 3)
            .background(TerminalTokens.phosphor.opacity(0.08))
            .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.75)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(itemAccessibilityLabel(item)))
        .accessibilityHint(Text("dailyPlan.timeline.selectHint"))
    }

    private func makeSnapshot(for date: Date) -> DailyPlanSnapshot {
        DailyPlanAggregator.snapshot(date: date, courses: courses, rules: rules, attendance: attendance,
            studyTasks: studyTasks, studySessions: studySessions, plannedWorkouts: plannedWorkouts,
            workoutPlans: workoutPlans, completedWorkouts: completedWorkouts, calendarEntries: calendarEntries,
            assessments: assessments, universityCourses: universityCourses, debts: debts,
            recurringTransactions: recurringTransactions, notes: notes, organizationProjects: organizationProjects, organizationTasks: organizationTasks,
            taskPlacements: taskPlacements, focusSessions: focusSessions)
    }

    private var plannerSettings: DailyPlannerSettings {
        DailyPlannerSettings(workStartMinutes: plannerWorkStart, workEndMinutes: plannerWorkEnd,
                             bufferMinutes: plannerBuffer, defaultTaskDurationMinutes: plannerDefaultDuration)
    }

    private var plannerFixedItems: [PlannerFixedItem] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        var values = snapshot.lessons.map { PlannerFixedItem(id: $0.id, title: $0.title, start: $0.start, end: $0.end) }
        values += calendarEntries.filter { !$0.isAllDay && intersectsPlannerDay($0.startDate, $0.endDate, day: day, calendar: calendar) }
            .map { PlannerFixedItem(id: "calendar:\($0.id)", title: $0.title, start: $0.startDate, end: max($0.endDate, $0.startDate.addingTimeInterval(600))) }
        values += taskPlacements.filter { calendar.isDate($0.planDate, inSameDayAs: day) }.map {
            PlannerFixedItem(id: "accepted:\($0.id)", title: String(localized: "planner.acceptedPlacement"), start: $0.startDate, end: $0.endDate)
        }
        return values
    }

    private var plannerCandidates: [PlannerCandidate] {
        let calendar = Calendar.current
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
        let accepted = Set(taskPlacements.filter { calendar.isDate($0.planDate, inSameDayAs: selectedDate) }
            .map { "\($0.source.rawValue):\($0.sourceRecordID.uuidString.lowercased())" })
        var values: [PlannerCandidate] = studyTasks.filter {
            $0.status != .completed && $0.status != .cancelled && ($0.dueDate == nil || $0.dueDate! < dayEnd)
        }.map {
            PlannerCandidate(source: .studyTask, recordID: $0.id, title: $0.title, durationMinutes: max($0.estimatedMinutes, 10),
                             dueDate: $0.dueDate, priorityRank: studyPriorityRank($0.priority))
        }
        values += organizationTasks.filter {
            ($0.status == .planned || $0.status == .active) && ($0.dueDate == nil || $0.dueDate! < dayEnd)
        }.map {
            PlannerCandidate(source: .organizationTask, recordID: $0.id, title: $0.title, durationMinutes: plannerDefaultDuration,
                             dueDate: $0.dueDate, priorityRank: organizationPriorityRank($0.priority))
        }
        values += calendarEntries.filter {
            $0.kind != .event && $0.isAllDay && !$0.isCompleted && $0.startDate < dayEnd
        }.map {
            PlannerCandidate(source: .calendarTask, recordID: $0.id, title: $0.title, durationMinutes: plannerDefaultDuration,
                             dueDate: $0.startDate, priorityRank: $0.kind == .reminder ? 3 : 2)
        }
        return values.filter { !accepted.contains($0.id) }
    }

    private func studyPriorityRank(_ priority: StudyTaskPriority) -> Int {
        switch priority { case .low: 1; case .normal: 2; case .high: 3; case .critical: 4 }
    }
    private func organizationPriorityRank(_ priority: OrganizationPriority) -> Int {
        switch priority { case .low: 1; case .normal: 2; case .high: 3; case .critical: 4 }
    }
    private func intersectsPlannerDay(_ start: Date, _ end: Date, day: Date, calendar: Calendar) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        return start < next && end > day
    }
    private func newSchedule() {
        switch DailyPlanNewItemPolicy.nextStep(courseCount: courses.count) {
        case .createCourse:
            prerequisiteCourseSaved = false
            statusKey = "dailyPlan.status.courseRequired"
            statusKind = .warning
            creatingPrerequisiteCourse = true
        case .createSchedule:
            creatingRule = true
        }
    }

    private func continueAfterPrerequisiteCourse() {
        guard prerequisiteCourseSaved else { return }
        prerequisiteCourseSaved = false
        statusKey = "dailyPlan.status.courseCreated"
        statusKind = .success
        Task { @MainActor in
            await Task.yield()
            if !courses.isEmpty { creatingRule = true }
        }
    }
    private func deleteSchedule() { guard let deletingRule else { return }; context.delete(deletingRule); do { try context.save(); statusKey = "dailyPlan.status.scheduleDeleted"; statusKind = .success } catch { statusKey = "dailyPlan.status.error"; statusKind = .error }; self.deletingRule = nil }
    private func mark(_ occurrence: LessonOccurrence, _ status: AttendanceStatus) { do { try DailyPlanAttendanceService.mark(occurrence: occurrence, status: status, records: attendance, context: context); statusKey = "dailyPlan.status.attendanceSaved"; statusKind = .success } catch { statusKey = "dailyPlan.status.error"; statusKind = .error } }
    private func toggleTask(_ item: DailyPlanItem) {
        do {
            _ = try DailyPlanTaskCompletionService.toggle(
                item: item,
                studyTasks: studyTasks,
                organizationTasks: organizationTasks,
                calendarEntries: calendarEntries,
                plannedWorkouts: plannedWorkouts,
                context: context
            )
            statusKey = "dailyPlan.status.taskToggled"
            statusKind = .success
        } catch {
            statusKey = "dailyPlan.status.taskToggleFailed"
            statusKind = .error
        }
    }
    private func attendanceStatus(for occurrence: LessonOccurrence) -> AttendanceStatus? {
        attendance.first { $0.occurrenceID == occurrence.id }?.status
    }
    private func selectDate(_ date: Date, switchToToday: Bool) {
        selectedDate = date
        selectedItemID = nil
        if switchToToday { mode = .today }
    }
    private func shiftDate(_ direction: Int) {
        let component: Calendar.Component = mode == .month ? .month : (mode == .week ? .weekOfYear : .day)
        selectedDate = Calendar.current.date(byAdding: component, value: direction, to: selectedDate) ?? selectedDate
        selectedItemID = nil
    }
    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !selectableItems.isEmpty else { return }
        let current = selectedItemID.flatMap { id in selectableItems.firstIndex { $0.id == id } } ?? 0
        switch direction {
        case .down, .right: selectedItemID = selectableItems[min(current + 1, selectableItems.count - 1)].id
        case .up, .left: selectedItemID = selectableItems[max(current - 1, 0)].id
        @unknown default: break
        }
    }
    private func openSelection() {
        if let item = selectableItems.first(where: { $0.id == selectedItemID }) { appState.open(item.source.route) }
    }
    private func focusRequest(for item: DailyPlanItem) -> FocusRequest? {
        guard let recordID = item.recordID, !item.isCompleted else { return nil }
        switch item.kind {
        case .studyTask:
            guard let task = studyTasks.first(where: { $0.id == recordID }), task.status != .cancelled else { return nil }
            return FocusRequest(source: .studyTask, sourceRecordID: task.id, courseID: task.courseID,
                                title: task.title, plannedDurationSeconds: max(task.estimatedMinutes, 10) * 60)
        case .organizationTask:
            guard let task = organizationTasks.first(where: { $0.id == recordID }), task.status != .cancelled else { return nil }
            return FocusRequest(source: .organizationTask, sourceRecordID: task.id, title: task.title,
                                plannedDurationSeconds: plannerDefaultDuration * 60)
        case .calendar:
            guard let entry = calendarEntries.first(where: { $0.id == recordID }), entry.kind != .event, !entry.isCompleted else { return nil }
            let interval = item.start.flatMap { start in item.end.map { Int($0.timeIntervalSince(start)) } }
            return FocusRequest(source: .calendarTask, sourceRecordID: entry.id, courseID: entry.courseID,
                                title: entry.title, plannedDurationSeconds: max(interval ?? plannerDefaultDuration * 60, 60))
        default: return nil
        }
    }
    private func symbol(_ item: DailyPlanItem) -> String { switch item.kind { case .lesson: "book.closed"; case .freeTime: "pause"; case .studyTask: "checklist"; case .organizationTask: "square.grid.2x2"; case .studySession, .focusSession: "timer"; case .gym: "figure.strengthtraining.traditional"; case .calendar: "calendar"; case .assessment: "graduationcap"; case .financeDue: "creditcard"; case .pinnedNote: "pin" } }
    private func itemAccessibilityLabel(_ item: DailyPlanItem) -> String {
        let time = item.start?.formatted(date: .omitted, time: .shortened) ?? ""
        let source = String(localized: String.LocalizationValue(item.source.route.titleKey))
        let duration = DailyPlanTimelinePolicy.isPointInTime(item) ? String(localized: "dailyPlan.durationUnspecified") : ""
        return [time, item.title, item.subtitle, source, duration].filter { !$0.isEmpty }.joined(separator: ", ")
    }
    private func shortTime(_ item: DailyPlanItem) -> String {
        item.start?.formatted(date: .omitted, time: .shortened) ?? "—"
    }
}

private struct DailyPlanPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TerminalTokens.surface.opacity(0.28))
            .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.62)))
    }
}

private extension View {
    func dashboardPanel() -> some View { modifier(DailyPlanPanelModifier()) }
}

private struct DailyPlanRuleEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let rule: StudyScheduleRule?
    let courses: [Course]
    @State private var courseID: UUID
    @State private var weekday: Int
    @State private var time: Date
    @State private var duration: Int
    @State private var location: String
    @State private var effectiveStart: Date
    @State private var effectiveEndEnabled: Bool
    @State private var effectiveEnd: Date
    @State private var error: String?
    private let provisionalMetadata: ProvisionalScheduleMetadata?

    init(rule: StudyScheduleRule?, courses: [Course], selectedDate: Date) {
        self.rule = rule; self.courses = courses
        let calendar = Calendar.current; let minutes = rule?.startMinutes ?? 540; let base = calendar.startOfDay(for: selectedDate)
        provisionalMetadata = rule.flatMap { ScheduleRulePresentationPolicy.metadata(for: $0) }
        _courseID = State(initialValue: rule?.courseID ?? courses.first?.id ?? UUID())
        _weekday = State(initialValue: rule?.weekday ?? calendar.component(.weekday, from: selectedDate))
        _time = State(initialValue: calendar.date(byAdding: .minute, value: minutes, to: base) ?? selectedDate)
        _duration = State(initialValue: rule?.durationMinutes ?? 50); _location = State(initialValue: provisionalMetadata == nil ? (rule?.locationOverride ?? "") : "")
        _effectiveStart = State(initialValue: rule?.effectiveStart ?? selectedDate); _effectiveEndEnabled = State(initialValue: rule?.effectiveEnd != nil)
        _effectiveEnd = State(initialValue: rule?.effectiveEnd ?? calendar.date(byAdding: .month, value: 4, to: selectedDate) ?? selectedDate)
    }
    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: rule == nil ? "dailyPlan.editor.new" : "dailyPlan.editor.edit") {
            TerminalForm {
                Picker("dailyPlan.editor.course", selection: $courseID) { ForEach(courses) { Text($0.name).tag($0.id) } }
                Picker("dailyPlan.editor.weekday", selection: $weekday) { ForEach(1...7, id: \.self) { value in Text(weekdayName(value)).tag(value) } }
                DatePicker("dailyPlan.editor.time", selection: $time, displayedComponents: .hourAndMinute)
                Stepper(value: $duration, in: 10...720, step: 5) { Text("\(duration) dk") }
                if let provisionalMetadata {
                    Label(provisionalMetadata.displaySummary(linkedCourse: courses.first(where: { $0.id == courseID })), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(TerminalTokens.warning).accessibilityIdentifier("dailyPlan.schedule.provisional")
                } else {
                    TextField("dailyPlan.editor.location", text: $location)
                }
                DatePicker("dailyPlan.editor.start", selection: $effectiveStart, displayedComponents: .date)
                Toggle("dailyPlan.editor.endEnabled", isOn: $effectiveEndEnabled)
                if effectiveEndEnabled { DatePicker("dailyPlan.editor.end", selection: $effectiveEnd, displayedComponents: .date) }
            }.frame(height: 390)
            if let error { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error) }
            HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) }
        }.padding() }.frame(width: 560, height: 570)
            .accessibilityIdentifier("dailyPlan.scheduleEditor")
            .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }
    private func save() {
        guard courses.contains(where: { $0.id == courseID }) else { error = String(localized: "dailyPlan.validation.course"); return }
        guard !effectiveEndEnabled || effectiveEnd >= effectiveStart else { error = String(localized: "dailyPlan.validation.end"); return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time); let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let storedMetadata = provisionalMetadata?.encodedValue ?? location.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule { rule.courseID = courseID; rule.weekday = weekday; rule.startMinutes = minutes; rule.durationMinutes = duration; rule.locationOverride = storedMetadata; rule.effectiveStart = effectiveStart; rule.effectiveEnd = effectiveEndEnabled ? effectiveEnd : nil; rule.updatedAt = .now }
        else { context.insert(StudyScheduleRule(courseID: courseID, weekday: weekday, startMinutes: minutes, durationMinutes: duration, effectiveStart: effectiveStart, effectiveEnd: effectiveEndEnabled ? effectiveEnd : nil, locationOverride: storedMetadata)) }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
    private func weekdayName(_ weekday: Int) -> String { let names = Calendar.current.weekdaySymbols; return names.indices.contains(weekday - 1) ? names[weekday - 1] : "\(weekday)" }
}
