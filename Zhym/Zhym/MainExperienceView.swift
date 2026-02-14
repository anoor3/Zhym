import SwiftUI
import UIKit

private enum RootTab: String, CaseIterable, Identifiable {
    case workout, exercises, library, progress, settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .workout: return "figure.strengthtraining.traditional"
        case .exercises: return "dumbbell"
        case .library: return "books.vertical"
        case .progress: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .workout: return "Workout"
        case .exercises: return "Exercises"
        case .library: return "Library"
        case .progress: return "Progress"
        case .settings: return "Settings"
        }
    }
}

struct MainExperienceView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: RootTab = .workout
    @State private var showingSessionRunner = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 21/255, green: 28/255, blue: 46/255, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 247/255, green: 211/255, blue: 33/255, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 247/255, green: 211/255, blue: 33/255, alpha: 1)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 129/255, green: 145/255, blue: 184/255, alpha: 1)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(red: 129/255, green: 145/255, blue: 184/255, alpha: 1)]
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayScreen(onBeginSession: {
                showingSessionRunner = true
            })
                .tabItem { Label(RootTab.workout.label, systemImage: RootTab.workout.icon) }
                .tag(RootTab.workout)

            ExerciseCatalogView(startSession: {
                showingSessionRunner = true
            })
                .tabItem { Label(RootTab.exercises.label, systemImage: RootTab.exercises.icon) }
                .tag(RootTab.exercises)

            ProgramLibraryView()
                .tabItem { Label(RootTab.library.label, systemImage: RootTab.library.icon) }
                .tag(RootTab.library)

            ProgressScreen()
                .tabItem { Label(RootTab.progress.label, systemImage: RootTab.progress.icon) }
                .tag(RootTab.progress)

            ProfileScreen()
                .tabItem { Label(RootTab.settings.label, systemImage: RootTab.settings.icon) }
                .tag(RootTab.settings)
        }
        .preferredColorScheme(.dark)
        .accentColor(ZhymPalette.highlight)
        .fullScreenCover(isPresented: $showingSessionRunner) {
            SessionRunnerView()
                .environmentObject(appState)
        }
    }
}

// MARK: - TODAY

struct TodayScreen: View {
    @EnvironmentObject private var appState: AppState
    let onBeginSession: () -> Void
    @State private var activeGuide: ExerciseGuide?
    @State private var showingCheckIn = false
    @State private var activeHeroAction: HeroAction?
    @State private var timelineAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var previewSessionIndex: Int = 0

    private var plan: TrainingPlan? { appState.trainingPlan }
    private var session: WorkoutSession? { plan?.sessions[safe: previewSessionIndex] }
    private var profile: ZhymUserProfile? { appState.activeProfile }

    private var stats: [SessionStat] {
        guard let session else { return [] }
        return SessionStat.make(for: session, profile: profile)
    }

    private var timelineEntries: [TimelineEntry] {
        let calendar = Calendar.current
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: timelineAnchor) ?? timelineAnchor
            if calendar.isDate(date, inSameDayAs: Date()) {
                return TimelineEntry(date: date, status: .today)
            }
            if appState.workoutLogs.contains(where: { calendar.isDate($0.completedAt, inSameDayAs: date) }) {
                return TimelineEntry(date: date, status: .completed)
            }
            return TimelineEntry(date: date, status: date < Date() ? .rest : .upcoming)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                HeroPlanHeader(
                    profileName: profile?.trainingPreferences.objective.rawValue ?? "Zhym Program",
                    weekText: plan != nil ? "Week \(plan!.week)" : "Calibrating",
                    sessionTitle: session?.name ?? "Recovery Day",
                    highlight: session?.focus ?? "Intentional movement",
                    openAction: { action in activeHeroAction = action },
                    startSession: {
                        appState.activeSessionIndex = previewSessionIndex
                        onBeginSession()
                    }
                )

                DayTimelineView(
                    entries: timelineEntries,
                    selectedDate: selectedDate,
                    moveWeek: { shift in
                        timelineAnchor = Calendar.current.date(byAdding: .day, value: shift * 7, to: timelineAnchor) ?? timelineAnchor
                        timelineAnchor = Calendar.current.startOfDay(for: timelineAnchor)
                    },
                    selectDate: { date in
                        let normalized = Calendar.current.startOfDay(for: date)
                        selectedDate = normalized
                        updatePreviewSession(for: normalized)
                        ensureDateVisible(normalized)
                    }
                )

                if let session {
                    SessionShowcase(
                        session: session,
                        stats: stats,
                        openGuide: { exercise in
                            activeGuide = GuidanceLibrary.guide(for: exercise.name)
                        },
                        launch: {
                            appState.activeSessionIndex = previewSessionIndex
                            onBeginSession()
                        }
                    )
                } else {
                    EmptySessionPlaceholder()
                }

                VStack(spacing: 18) {
                    ConsistencyCard(score: appState.disciplineScore, fatigueNotice: appState.fatigueAdvisory) {
                        showingCheckIn = true
                    }

                    if let plan = appState.nutritionPlan {
                        NutritionPulseCard(plan: plan)
                    } else {
                        GenerateNutritionPrompt()
                    }
                }

                RecoveryHighlights()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
        }
        .background(ZhymPalette.background.ignoresSafeArea())
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideSheet(guide: guide)
        }
        .sheet(isPresented: $showingCheckIn) {
            DisciplineCheckInSheet()
                .environmentObject(appState)
        }
        .sheet(item: $activeHeroAction) { action in
            switch action {
            case .schedule:
                ScheduleSheet(plan: plan, anchor: timelineAnchor) { date in
                    let normalized = Calendar.current.startOfDay(for: date)
                    selectedDate = normalized
                    updatePreviewSession(for: normalized)
                    ensureDateVisible(normalized)
                }
                .presentationDetents([.medium])
            case .adjust:
                AdjustPlanSheet()
                    .presentationDetents([.medium])
            case .rewards:
                RewardsSheet()
                    .presentationDetents([.fraction(0.4)])
            }
        }
        .onAppear {
            previewSessionIndex = appState.activeSessionIndex
            selectedDate = Calendar.current.startOfDay(for: Date())
            timelineAnchor = selectedDate
        }
        .onChange(of: appState.activeSessionIndex) { _, newValue in
            previewSessionIndex = newValue
        }
        .onChange(of: appState.trainingPlan?.id) { _, _ in
            previewSessionIndex = appState.activeSessionIndex
        }
    }
}

private extension TodayScreen {
    func updatePreviewSession(for date: Date) {
        guard let plan = appState.trainingPlan, !plan.sessions.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        let offset = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        let count = plan.sessions.count
        let normalized = ((appState.activeSessionIndex + offset) % count + count) % count
        previewSessionIndex = normalized
        ensureDateVisible(target)
    }

    func ensureDateVisible(_ date: Date) {
        let start = timelineAnchor
        guard let end = Calendar.current.date(byAdding: .day, value: 6, to: start) else { return }
        if date < start {
            timelineAnchor = date
        } else if date > end {
            timelineAnchor = Calendar.current.date(byAdding: .day, value: -6, to: date) ?? timelineAnchor
        }
    }
}

private enum ToolbarAction: String, Identifiable {
    case rewards, calendar, filters
    var id: String { rawValue }
}

private struct WorkoutToolbar: View {
    var profileName: String
    var selectAction: (ToolbarAction) -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MY PLAN")
                    .font(ZhymTypography.label(12, weight: .medium))
                    .foregroundStyle(ZhymPalette.accent)
                    .tracking(1.2)
                HStack(spacing: 6) {
                    Text(profileName)
                        .font(ZhymTypography.display(28))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                ToolbarIconButton(systemName: "gift.fill", highlight: true) {
                    selectAction(.rewards)
                }
                ToolbarIconButton(systemName: "calendar") {
                    selectAction(.calendar)
                }
                ToolbarIconButton(systemName: "slider.horizontal.3") {
                    selectAction(.filters)
                }
            }
        }
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    var highlight: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(highlight ? ZhymPalette.background : ZhymPalette.accent)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlight ? ZhymPalette.highlight : ZhymPalette.overlay)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct RewardsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Rewards")
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)
            Text("Build streaks to unlock recovery kits, merch, and invite-only Zhym labs.")
                .font(ZhymTypography.label(15))
                .foregroundStyle(ZhymPalette.accent)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.primaryZhym)
        }
        .padding(32)
        .background(ZhymPalette.background.ignoresSafeArea())
    }
}

private struct ScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan?
    let anchor: Date
    let selectDate: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(ZhymTypography.display(30))
                .foregroundStyle(.white)
            if let plan {
                ForEach(Array(plan.sessions.enumerated()), id: \.offset) { pair in
                    let index = pair.offset
                    let session = pair.element
                    Button {
                        let date = Calendar.current.date(byAdding: .day, value: index, to: anchor) ?? anchor
                        selectDate(date)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayLabel(for: index))
                                    .font(ZhymTypography.label(13))
                                    .foregroundStyle(ZhymPalette.accent)
                                Text(session.name)
                                    .font(ZhymTypography.label(16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(session.focus)
                                    .font(ZhymTypography.label(13))
                                    .foregroundStyle(ZhymPalette.accent)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ZhymPalette.accent)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 18).fill(ZhymPalette.surface))
                    }
                }
            } else {
                Text("Generate a plan to view your detailed schedule.")
                    .font(ZhymTypography.label(15))
                    .foregroundStyle(ZhymPalette.accent)
            }
            Button("Close") { dismiss() }
                .buttonStyle(.secondaryZhym)
        }
        .padding(24)
        .background(ZhymPalette.background.ignoresSafeArea())
    }

    private func dayLabel(for index: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: index, to: anchor) ?? anchor
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

private struct AdjustPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var split: TrainingSplit = .pushPullLegs
    @State private var sessionsPerWeek: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjust Plan")
                .font(ZhymTypography.display(30))
                .foregroundStyle(.white)
            Picker("Split", selection: $split) {
                ForEach([TrainingSplit.pushPullLegs, .upperLower, .fullBody]) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Stepper("Sessions per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 3...6)
                .foregroundStyle(.white)

            Button("Apply soon") {
                dismiss()
            }
            .buttonStyle(.primaryZhym)
        }
        .padding(24)
        .background(ZhymPalette.background.ignoresSafeArea())
    }
}

private enum HeroAction: Identifiable {
    case schedule, adjust, rewards
    var id: String {
        switch self {
        case .schedule: return "schedule"
        case .adjust: return "adjust"
        case .rewards: return "rewards"
        }
    }
}

private struct HeroPlanHeader: View {
    var profileName: String
    var weekText: String
    var sessionTitle: String
    var highlight: String
    var openAction: (HeroAction) -> Void
    var startSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileName.uppercased())
                        .font(ZhymTypography.label(12, weight: .medium))
                        .foregroundStyle(ZhymPalette.accent.opacity(0.8))
                        .tracking(3)
                    Text(weekText)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                    Text(sessionTitle)
                        .font(ZhymTypography.display(40))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(highlight)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.aurora)
                        .opacity(0.9)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        openAction(.rewards)
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                            .background(Circle().fill(ZhymPalette.slate))
                    }
                    .buttonStyle(.plain)

                    Button {
                        openAction(.adjust)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                            .background(Circle().fill(ZhymPalette.slate))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button {
                    openAction(.schedule)
                } label: {
                    Label("Schedule", systemImage: "calendar")
                        .zhymCapsule(background: ZhymPalette.slate.opacity(0.6), foreground: .white)
                }
                Button(action: startSession) {
                    Text("Launch Session")
                        .font(ZhymTypography.label(15, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(ZhymPalette.highlight)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [ZhymPalette.wine.opacity(0.8), ZhymPalette.abyss], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .zhymGlowBorder()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct SessionShowcase: View {
    let session: WorkoutSession
    let stats: [SessionStat]
    let openGuide: (ExercisePrescription) -> Void
    let launch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 26)
                    .fill(ZhymPalette.primaryGradient())
                    .frame(height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(ZhymPalette.aurora.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "figure.strengthtraining.functional")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160)
                            .opacity(0.15)
                            .offset(x: 80, y: -30),
                        alignment: .topTrailing
                    )
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.name)
                        .font(ZhymTypography.display(32))
                        .foregroundStyle(.white)
                    Text(session.focus)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                    Button("Begin now", action: launch)
                        .buttonStyle(.primaryZhym)
                        .padding(.top, 8)
                        .frame(maxWidth: 220)
                }
                .padding(24)
            }

            if !stats.isEmpty {
                SessionStatRow(stats: stats)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(session.exercises.prefix(3))) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(ZhymTypography.label(16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(exercise.sets)x \(exercise.reps) · \(exercise.intent)")
                                .font(ZhymTypography.label(13))
                                .foregroundStyle(ZhymPalette.accent)
                        }
                        Spacer()
                        Button {
                            openGuide(exercise)
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(ZhymPalette.accent)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 18).fill(ZhymPalette.slate.opacity(0.6)))
                }
                if session.exercises.count > 3 {
                    Text("+\(session.exercises.count - 3) more movements scripted")
                        .font(ZhymTypography.label(13))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }
        }
        .zhymCard()
    }
}

private struct SessionStatRow: View {
    let stats: [SessionStat]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: stat.icon)
                        .foregroundStyle(ZhymPalette.ember)
                    Text(stat.value)
                        .font(ZhymTypography.display(26))
                        .foregroundStyle(.white)
                    Text(stat.label)
                        .font(ZhymTypography.label(12))
                        .foregroundStyle(ZhymPalette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(ZhymPalette.slate.opacity(0.7)))
            }
        }
    }
}

private struct DualCardStack<First: View, Second: View>: View {
    let first: First
    let second: Second

    init(@ViewBuilder first: () -> First, @ViewBuilder second: () -> Second) {
        self.first = first()
        self.second = second()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            first
                .frame(maxWidth: .infinity)
            second
                .frame(maxWidth: .infinity)
        }
    }
}

private struct GenerateNutritionPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition intelligence")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text("Complete onboarding to unlock calorie prescriptions and chef-designed meals.")
                .font(ZhymTypography.label(14))
                .foregroundStyle(.white)
        }
        .zhymCard()
    }
}

private struct RecoveryHighlights: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery intelligence")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack(spacing: 16) {
                RecoveryTile(title: "Nervous system", value: "Prime", detail: "+4% vs last week")
                RecoveryTile(title: "Sleep debit", value: "Low", detail: "6h 52m avg")
            }
        }
    }

    struct RecoveryTile: View {
        let title: String
        let value: String
        let detail: String
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(ZhymTypography.label(11))
                    .foregroundStyle(ZhymPalette.accent)
                Text(value)
                    .font(ZhymTypography.display(26))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(ZhymTypography.label(12))
                    .foregroundStyle(ZhymPalette.accent)
            }
            .zhymCard()
        }
    }
}

private struct TimelineEntry: Identifiable {
    let id = UUID()
    let date: Date
    let status: TimelineStatus
}

private enum TimelineStatus {
    case completed, today, upcoming, rest

    var color: Color {
        switch self {
        case .completed:
            return ZhymPalette.aurora
        case .today:
            return ZhymPalette.ember
        case .upcoming:
            return ZhymPalette.aurora.opacity(0.8)
        case .rest:
            return ZhymPalette.accent
        }
    }
}

private struct DayTimelineView: View {
    let entries: [TimelineEntry]
    let selectedDate: Date
    let moveWeek: (Int) -> Void
    let selectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { moveWeek(-1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(ZhymPalette.accent)
                        .padding(8)
                        .background(Circle().fill(ZhymPalette.slate))
                }
                Spacer()
                Text(monthTitle)
                    .font(ZhymTypography.label(14, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { moveWeek(1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ZhymPalette.accent)
                        .padding(8)
                        .background(Circle().fill(ZhymPalette.slate))
                }
            }
            HStack(spacing: 10) {
                ForEach(entries) { entry in
                    Button {
                        selectDate(entry.date)
                    } label: {
                        VStack(spacing: 6) {
                            Text(dayLabelFormatter.string(from: entry.date).uppercased())
                                .font(ZhymTypography.label(12, weight: Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) ? .semibold : .regular))
                                .foregroundStyle(Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) ? .white : ZhymPalette.accent)
                            Text(dayNumber(from: entry.date))
                                .font(ZhymTypography.numeric(20))
                                .foregroundStyle(entry.status.color)
                            Circle()
                                .fill(entry.status == .rest ? ZhymPalette.accent.opacity(0.3) : entry.status.color)
                                .frame(width: 8, height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) ? ZhymPalette.slate.opacity(0.9) : ZhymPalette.slate.opacity(0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedDate)
    }

    private func dayNumber(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: "%02d", day)
    }
}

private struct SessionStat: Identifiable {
    let id: UUID
    let icon: String
    let value: String
    let label: String

    static func make(for session: WorkoutSession, profile: ZhymUserProfile?) -> [SessionStat] {
        let exerciseCount = session.exercises.count
        let duration = estimatedDuration(for: session)
        let calories = estimatedCalories(for: session, profile: profile)
        return [
            SessionStat(id: UUID(), icon: "bolt.fill", value: "\(exerciseCount)", label: "Exercises"),
            SessionStat(id: UUID(), icon: "clock.fill", value: "\(duration) min", label: "Duration"),
            SessionStat(id: UUID(), icon: "flame.fill", value: "\(calories) cal", label: "Energy")
        ]
    }

    private static func estimatedDuration(for session: WorkoutSession) -> Int {
        let sets = session.exercises.map(\.sets).reduce(0, +)
        return min(max(sets * 3 + 25, 35), 90)
    }

    private static func estimatedCalories(for session: WorkoutSession, profile: ZhymUserProfile?) -> Int {
        let sets = Double(session.exercises.map(\.sets).reduce(0, +))
        let weight = profile?.metrics.weightKg ?? 78
        return Int((sets * 6.5) + Double(weight) * 1.2)
    }
}

private struct EmptySessionPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No workout scheduled")
                .font(ZhymTypography.display(28))
                .foregroundStyle(.white)
            Text("Complete onboarding to generate your first Zhym program.")
                .font(ZhymTypography.label(15))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct ConsistencyCard: View {
    let score: Int
    let fatigueNotice: String?
    let openCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency")
                    .font(ZhymTypography.label(15, weight: .medium))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Text("\(score)")
                    .font(ZhymTypography.display(30))
                    .foregroundStyle(ZhymPalette.highlight)
            }

            Text(fatigueNotice ?? "Steady momentum. Log your day to keep insights sharp.")
                .font(ZhymTypography.label(14))
                .foregroundStyle(fatigueNotice == nil ? ZhymPalette.accent : ZhymPalette.warning)

            Button("Daily check-in", action: openCheckIn)
                .buttonStyle(.secondaryZhym)
        }
        .zhymCard()
    }
}

private struct NutritionPulseCard: View {
    let plan: NutritionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition pulse")
                    .font(ZhymTypography.label(15, weight: .medium))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(ZhymPalette.accent)
            }

            HStack(spacing: 16) {
                MacroHighlight(icon: "leaf", value: "\(plan.calories)", label: "Calories")
                MacroHighlight(icon: "bolt.heart", value: "\(plan.protein) g", label: "Protein")
                MacroHighlight(icon: "drop", value: "\(plan.carbs) g", label: "Carbs")
            }

            Text("Targets auto-adjust weekly based on compliance and scale trends.")
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct MacroHighlight: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(ZhymPalette.highlight)
            Text(value)
                .font(ZhymTypography.display(22))
                .foregroundStyle(.white)
            Text(label)
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SESSION RUNNER

struct SessionRunnerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var sessionIndex: Int = 0
    @State private var exerciseIndex: Int = 0
    @State private var restRemaining: Double = 0
    @State private var isRestRunning = false
    @State private var timer: Timer?
    @State private var currentSet: Int = 1
    @State private var sessionCompleted = false
    @State private var lastCompletedSession: WorkoutSession?
    @State private var activeGuide: ExerciseGuide?
    @State private var restTargetDate: Date?

    private var currentSession: WorkoutSession? {
        guard let plan = appState.trainingPlan, !plan.sessions.isEmpty else { return nil }
        let safeIndex = min(sessionIndex, plan.sessions.count - 1)
        return plan.sessions[safeIndex]
    }

    private var currentExercise: ExercisePrescription? {
        guard let session = currentSession, !session.exercises.isEmpty else { return nil }
        let safeIndex = min(exerciseIndex, session.exercises.count - 1)
        return session.exercises[safeIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ZhymPalette.highlight)
                        .padding(10)
                        .background(Circle().fill(ZhymPalette.surface))
                }
                Text("Train")
                    .font(ZhymTypography.display(32))
                    .foregroundStyle(.white)
                Spacer()
            }

            if sessionCompleted, let completed = lastCompletedSession {
                SessionCompleteView(session: completed, nextSession: currentSession, proceed: prepareNextSession)
            } else if let session = currentSession, let exercise = currentExercise {
                VStack(alignment: .leading, spacing: 32) {
                    Text(session.name)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(exercise.name)
                                .font(ZhymTypography.display(32))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                activeGuide = GuidanceLibrary.guide(for: exercise.name)
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 22, weight: .thin))
                                    .foregroundStyle(ZhymPalette.platinum)
                            }
                        }
                        Text("Exercise \(exerciseIndex + 1) of \(session.exercises.count) • Set \(currentSet) of \(exercise.sets)")
                            .font(ZhymTypography.label(15))
                            .foregroundStyle(ZhymPalette.accent)
                    }

                    HStack(spacing: 16) {
                        trainMetric(title: "Sets", value: "\(exercise.sets)")
                        trainMetric(title: "Prescription", value: exercise.reps)
                        trainMetric(title: "Intent", value: exercise.intent)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rest timer")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    Text("\(Int(restRemaining))s")
                        .font(ZhymTypography.numeric(56))
                        .foregroundStyle(.white)
                    Button(isRestRunning ? "Restart rest" : "Start rest") {
                        startRestTimer(duration: exercise.restSeconds)
                    }
                    .buttonStyle(.secondaryZhym)
                }
                .zhymCard()

                    Button("Complete set") {
                        completeSet(in: session, exercise: exercise)
                    }
                    .buttonStyle(.primaryZhym)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No session scheduled today")
                        .font(ZhymTypography.display(32))
                        .foregroundStyle(.white)
                    Text("Once a plan is generated, your prescriptions will appear here.")
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }

            Spacer()
        }
        .padding(24)
        .background(ZhymPalette.background.ignoresSafeArea())
        .onAppear {
            setSessionIndex(appState.activeSessionIndex)
            if restTargetDate == nil {
                resetTimer()
            } else {
                restartRestTick()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: currentExercise?.id) { _, _ in
            resetTimer()
        }
        .onChange(of: appState.trainingPlan?.id) { _, _ in
            setSessionIndex(0)
            exerciseIndex = 0
            resetTimer()
        }
        .onChange(of: appState.activeSessionIndex) { _, newIndex in
            if newIndex != sessionIndex {
                sessionIndex = newIndex
                resetTimer()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncRestRemaining()
            }
        }
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideSheet(guide: guide)
        }
    }

    private func resetTimer() {
        guard let exercise = currentExercise else { return }
        timer?.invalidate()
        restTargetDate = nil
        restRemaining = Double(exercise.restSeconds)
        isRestRunning = false
    }

    private func startRestTimer(duration: Int) {
        restTargetDate = Date().addingTimeInterval(Double(duration))
        restartRestTick()
    }

    private func restartRestTick() {
        timer?.invalidate()
        guard restTargetDate != nil else { return }
        isRestRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            syncRestRemaining()
        }
        syncRestRemaining()
    }

    private func syncRestRemaining() {
        guard let target = restTargetDate else {
            isRestRunning = false
            return
        }
        let remaining = max(0, target.timeIntervalSinceNow)
        restRemaining = remaining
        if remaining <= 0 {
            timer?.invalidate()
            restTargetDate = nil
            isRestRunning = false
        }
    }

    private func trainMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ZhymTypography.label(12))
                .foregroundStyle(ZhymPalette.accent)
            Text(value)
                .font(ZhymTypography.display(24))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func completeSet(in session: WorkoutSession, exercise: ExercisePrescription) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()

        if currentSet < exercise.sets {
            currentSet += 1
            startRestTimer(duration: exercise.restSeconds)
            generator.impactOccurred()
            return
        }

        if exerciseIndex < session.exercises.count - 1 {
            exerciseIndex += 1
            currentSet = 1
            resetTimer()
            generator.impactOccurred()
        } else {
            completeSession(session)
            generator.impactOccurred()
        }
    }

    private func completeSession(_ session: WorkoutSession) {
        timer?.invalidate()
        isRestRunning = false
        sessionCompleted = true
        lastCompletedSession = session
        appState.recordWorkout(session: session)

        if let plan = appState.trainingPlan, sessionIndex < plan.sessions.count - 1 {
            setSessionIndex(sessionIndex + 1)
        } else {
            setSessionIndex(0)
        }
        exerciseIndex = 0
        currentSet = 1
    }

    private func prepareNextSession() {
        sessionCompleted = false
        lastCompletedSession = nil
        resetTimer()
    }

    private func setSessionIndex(_ newValue: Int) {
        let clamped = max(0, newValue)
        sessionIndex = clamped
        if appState.activeSessionIndex != clamped {
            appState.activeSessionIndex = clamped
        }
    }
}

private struct SessionCompleteView: View {
    let session: WorkoutSession
    let nextSession: WorkoutSession?
    let proceed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session logged")
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)
            Text(session.name)
                .font(ZhymTypography.label(18))
                .foregroundStyle(ZhymPalette.accent)
            Text("Focus: \(session.focus)")
                .font(ZhymTypography.label(16))
                .foregroundStyle(.white)

            if let next = nextSession {
                Text("Next: \(next.name)")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
            }

            Button("Load next session") {
                proceed()
            }
            .buttonStyle(.primaryZhym)
        }
        .zhymCard()
    }
}

private struct ExerciseGuideSheet: View {
    let guide: ExerciseGuide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(guide.name)
                    .font(ZhymTypography.display(34))
                    .foregroundStyle(.white)
                Text(guide.intent.uppercased())
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                    .tracking(2)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Cues")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    ForEach(Array(guide.cues.enumerated()), id: \.offset) { pair in
                        let index = pair.offset
                        let cue = pair.element
                        HStack(alignment: .top, spacing: 8) {
                            Text(String(index + 1))
                                .font(ZhymTypography.label(13))
                                .foregroundStyle(ZhymPalette.accent)
                            Text(cue)
                                .font(ZhymTypography.label(16))
                                .foregroundStyle(.white)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Breathing")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    Text(guide.breathing)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Safety")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    Text(guide.safety)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(.white)
                }

                RoundedRectangle(cornerRadius: 24)
                    .fill(ZhymPalette.graphite)
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle")
                                .font(.system(size: 44, weight: .thin))
                                .foregroundStyle(ZhymPalette.platinum)
                            Text("Motion preview reserved for production build")
                                .font(ZhymTypography.label(14))
                                .foregroundStyle(ZhymPalette.accent)
                        }
                    )
            }
            .padding(28)
        }
        .background(ZhymPalette.charcoal.ignoresSafeArea())
    }
}

private struct DisciplineCheckInSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var completedTraining: Bool = true
    @State private var energyLevel: Double = 6
    @State private var sleepQuality: Double = 6
    @State private var stressLevel: Double = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Daily check-in")
                .font(ZhymTypography.display(30))
                .foregroundStyle(.white)
            Toggle("Training completed", isOn: $completedTraining)
                .toggleStyle(SwitchToggleStyle(tint: ZhymPalette.platinum))

            sliderBlock(title: "Energy", value: $energyLevel)
            sliderBlock(title: "Sleep quality", value: $sleepQuality)
            sliderBlock(title: "Stress", value: $stressLevel, reversed: true)

            Button("Submit status") {
                appState.recordDisciplineEntry(completedTraining: completedTraining, energyLevel: Int(energyLevel), sleepQuality: Int(sleepQuality), stressLevel: Int(stressLevel))
                dismiss()
            }
            .buttonStyle(.primaryZhym)
        }
        .padding(24)
        .background(ZhymPalette.charcoal.ignoresSafeArea())
    }

    private func sliderBlock(title: String, value: Binding<Double>, reversed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue))
                    .font(ZhymTypography.numeric(22))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: 1...10, step: 1)
                .tint(reversed ? ZhymPalette.warning : ZhymPalette.platinum)
        }
    }
}

// MARK: - EXERCISES

struct ExerciseCatalogView: View {
    @EnvironmentObject private var appState: AppState
    let startSession: () -> Void
    @State private var selectedEquipment: EquipmentFilter = .all
    @State private var selectedMuscle: MuscleFilter = .all
    @State private var selectedLevel: LevelFilter = .all
    @State private var searchText: String = ""
    @State private var activeGuide: ExerciseGuide?

    private var filteredExercises: [ExerciseLibraryItem] {
        ExerciseLibraryItem.demo.filter { item in
            (selectedEquipment == .all || item.equipment == selectedEquipment) &&
            (selectedMuscle == .all || item.muscle == selectedMuscle) &&
            (selectedLevel == .all || item.level == selectedLevel) &&
            (searchText.isEmpty || item.name.lowercased().contains(searchText.lowercased()))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Curated library")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    HStack {
                        Text("Exercises")
                            .font(ZhymTypography.display(44))
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Smart session") {
                            startSession()
                        }
                        .buttonStyle(.secondaryZhym)
                        .frame(width: 150)
                    }
                    Text("200+ guided movements with cinematic cues and elite swaps.")
                        .font(ZhymTypography.label(15))
                        .foregroundStyle(ZhymPalette.accent)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(ZhymPalette.slate.opacity(0.6))
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ZhymPalette.accent)
                        TextField("Search movements", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 48)

                FilterMenus(selectedEquipment: $selectedEquipment, selectedMuscle: $selectedMuscle, selectedLevel: $selectedLevel)

                ForEach(filteredExercises) { exercise in
                    ExerciseLibraryCard(exercise: exercise) {
                        activeGuide = GuidanceLibrary.guide(for: exercise.name)
                    }
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [ZhymPalette.night, ZhymPalette.abyss], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideSheet(guide: guide)
        }
    }
}

private struct FilterMenus: View {
    @Binding var selectedEquipment: EquipmentFilter
    @Binding var selectedMuscle: MuscleFilter
    @Binding var selectedLevel: LevelFilter

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(EquipmentFilter.allCases) { option in
                    Button(option.displayName) { selectedEquipment = option }
                }
            } label: {
                FilterChipLabel(title: "Equipment", value: selectedEquipment.displayName)
            }

            Menu {
                ForEach(MuscleFilter.allCases) { option in
                    Button(option.displayName) { selectedMuscle = option }
                }
            } label: {
                FilterChipLabel(title: "Muscles", value: selectedMuscle.displayName)
            }

            Menu {
                ForEach(LevelFilter.allCases) { option in
                    Button(option.displayName) { selectedLevel = option }
                }
            } label: {
                FilterChipLabel(title: "Level", value: selectedLevel.displayName)
            }
        }
    }
}

private struct FilterChipLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZhymTypography.label(11))
                    .foregroundStyle(ZhymPalette.accent)
                Text(value)
                    .font(ZhymTypography.label(14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .foregroundStyle(ZhymPalette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(ZhymPalette.surface))
    }
}

private enum EquipmentFilter: String, CaseIterable, Identifiable {
    case all, dumbbells, barbell, bodyweight, cables, machines
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all: return "All"
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .bodyweight: return "Bodyweight"
        case .cables: return "Cables"
        case .machines: return "Machines"
        }
    }
}

private enum MuscleFilter: String, CaseIterable, Identifiable {
    case all, chest, back, legs, shoulders, core
    var id: String { rawValue }
    var displayName: String {
        rawValue.capitalized
    }
}

private enum LevelFilter: String, CaseIterable, Identifiable {
    case all, beginner, intermediate, advanced
    var id: String { rawValue }
    var displayName: String {
        rawValue.capitalized
    }
}

private struct ExerciseLibraryItem: Identifiable {
    let id = UUID()
    let name: String
    let muscle: MuscleFilter
    let equipment: EquipmentFilter
    let level: LevelFilter
    let duration: String

    static let demo: [ExerciseLibraryItem] = [
        ExerciseLibraryItem(name: "Goblet Squat", muscle: .legs, equipment: .dumbbells, level: .beginner, duration: "45s"),
        ExerciseLibraryItem(name: "Tempo Bench Press", muscle: .chest, equipment: .barbell, level: .intermediate, duration: "60s"),
        ExerciseLibraryItem(name: "Ring Row", muscle: .back, equipment: .bodyweight, level: .beginner, duration: "40s"),
        ExerciseLibraryItem(name: "Front Rack Lunge", muscle: .legs, equipment: .barbell, level: .intermediate, duration: "50s"),
        ExerciseLibraryItem(name: "Half Kneeling Press", muscle: .shoulders, equipment: .dumbbells, level: .beginner, duration: "35s"),
        ExerciseLibraryItem(name: "Copenhagen Plank", muscle: .core, equipment: .bodyweight, level: .advanced, duration: "30s"),
        ExerciseLibraryItem(name: "Cable Fly", muscle: .chest, equipment: .cables, level: .intermediate, duration: "45s"),
        ExerciseLibraryItem(name: "Lat Pulldown", muscle: .back, equipment: .machines, level: .beginner, duration: "40s")
    ]
}

private struct ExerciseLibraryCard: View {
    let exercise: ExerciseLibraryItem
    let openGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(ZhymTypography.display(24))
                    .foregroundStyle(.white)
                Spacer()
                Text(exercise.level.displayName)
                    .font(ZhymTypography.label(13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(ZhymPalette.overlay))
                    .foregroundStyle(ZhymPalette.highlight)
            }
            Text(exercise.muscle.displayName + " • " + exercise.equipment.displayName)
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack {
                Label(exercise.duration, systemImage: "clock")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Button("View cues", action: openGuide)
                    .buttonStyle(.secondaryZhym)
            }
        }
        .zhymCard()
    }
}

// MARK: - LIBRARY

struct ProgramLibraryView: View {
    @State private var selectedEquipment: EquipmentFilter = .all
    @State private var selectedMuscle: MuscleFilter = .all
    @State private var selectedDuration: DurationFilter = .three
    @State private var activeProgram: ProgramLibraryItem?

    private var filteredPrograms: [ProgramLibraryItem] {
        ProgramLibraryItem.demo.filter { item in
            (selectedEquipment == .all || item.equipment == selectedEquipment) &&
            (selectedMuscle == .all || item.focus == selectedMuscle) &&
            (selectedDuration == .all || item.days == selectedDuration)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Program gallery")
                            .font(ZhymTypography.label(14))
                            .foregroundStyle(ZhymPalette.accent)
                        Text("Library")
                            .font(ZhymTypography.display(40))
                            .foregroundStyle(.white)
                        Text("Plug-and-play cycles curated by Zhym coaches.")
                            .font(ZhymTypography.label(15))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    Spacer()
                    Label("Premium", systemImage: "crown.fill")
                        .font(ZhymTypography.label(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(ZhymPalette.slate.opacity(0.7)))
                        .foregroundStyle(ZhymPalette.ember)
                }

                HStack(spacing: 12) {
                    Menu {
                        ForEach(EquipmentFilter.allCases) { option in
                            Button(option.displayName) { selectedEquipment = option }
                        }
                    } label: {
                        FilterChipLabel(title: "Equipment", value: selectedEquipment.displayName)
                    }

                    Menu {
                        ForEach(MuscleFilter.allCases) { option in
                            Button(option.displayName) { selectedMuscle = option }
                        }
                    } label: {
                        FilterChipLabel(title: "Focus", value: selectedMuscle.displayName)
                    }

                    Menu {
                        ForEach(DurationFilter.allCases) { option in
                            Button(option.displayName) { selectedDuration = option }
                        }
                    } label: {
                        FilterChipLabel(title: "Days", value: selectedDuration.displayName)
                    }
                }

                ForEach(filteredPrograms) { program in
                    ProgramLibraryCard(program: program) {
                        activeProgram = program
                    }
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [ZhymPalette.night, ZhymPalette.wine.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .sheet(item: $activeProgram) { program in
            ProgramDetailSheet(program: program)
        }
    }
}

private enum DurationFilter: String, CaseIterable, Identifiable {
    case all, three, four, five, six
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all: return "All"
        case .three: return "3 Days"
        case .four: return "4 Days"
        case .five: return "5 Days"
        case .six: return "6 Days"
        }
    }
}

private struct ProgramLibraryItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let split: String
    let days: DurationFilter
    let focus: MuscleFilter
    let equipment: EquipmentFilter
    let accent: Color

    static let demo: [ProgramLibraryItem] = [
        ProgramLibraryItem(title: "Get In Shape", subtitle: "Full Body Split", split: "Foundations", days: .three, focus: .legs, equipment: .dumbbells, accent: Color(red: 0.4, green: 0.8, blue: 0.3)),
        ProgramLibraryItem(title: "Get In Shape", subtitle: "Push/Pull Split", split: "Strength", days: .four, focus: .back, equipment: .barbell, accent: Color(red: 0.9, green: 0.8, blue: 0.2)),
        ProgramLibraryItem(title: "Get In Shape", subtitle: "Bro Split", split: "Hypertrophy", days: .five, focus: .chest, equipment: .machines, accent: Color(red: 0.5, green: 0.7, blue: 0.2))
    ]
}

private struct ProgramLibraryCard: View {
    let program: ProgramLibraryItem
    let preview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(program.title.uppercased())
                .font(ZhymTypography.label(12, weight: .semibold))
                .foregroundStyle(ZhymPalette.highlight)
            Text(program.subtitle)
                .font(ZhymTypography.display(28))
                .foregroundStyle(.white)
            Text(program.split)
                .font(ZhymTypography.label(15))
                .foregroundStyle(ZhymPalette.accent)

            HStack {
                Label(program.days.displayName, systemImage: "calendar")
                Label(program.focus.displayName, systemImage: "bolt")
                Label(program.equipment.displayName, systemImage: "dumbbell")
            }
            .font(ZhymTypography.label(13))
            .foregroundStyle(.white)

            Button("Preview cycle", action: preview)
                .buttonStyle(.primaryZhym)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(colors: [program.accent.opacity(0.4), ZhymPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
    }
}

private struct ProgramDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let program: ProgramLibraryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(program.subtitle)
                    .font(ZhymTypography.display(32))
                    .foregroundStyle(.white)
                Text("Split: \(program.split)")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(.white)
                Text("Days: \(program.days.displayName) • Focus: \(program.focus.displayName)")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Text("Equipment: \(program.equipment.displayName)")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Button("Add to Zhym plan") {}
                    .buttonStyle(.primaryZhym)
                Button("Close") { dismiss() }
                    .buttonStyle(.secondaryZhym)
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [ZhymPalette.night, ZhymPalette.abyss], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
}


// MARK: - PROGRESS

struct ProgressScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: ProgressMode = .activity
    @State private var range: ProgressRange = .all

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                Text("Progress")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                RangeChipRow(selection: $range)

                ProgressSegmentedControl(selection: $mode)

                if mode == .activity {
                    activitySection
                } else {
                    bodySection
                }
            }
            .padding(24)
        }
        .background(ZhymPalette.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var activitySection: some View {
        ProgressStatRow(stats: activityStats)

        ProgressCalendarView(logs: appState.workoutLogs)

        AchievementGrid()

        ExerciseGraphCard(points: ExerciseGraphPoint.sample)

        SetCompletionCard(
            completed: setsCompletedThisWeek(logs: appState.workoutLogs),
            target: targetSets(for: appState.trainingPlan)
        )

        if let adjustment = appState.weeklyAdjustment {
            WeeklyAdaptationCard(adjustment: adjustment)
        }

        WorkoutHistoryView(logs: appState.workoutLogs)
        HealthEducationStack()
    }

    @ViewBuilder
    private var bodySection: some View {
        MeasurementOverviewCard(weight: currentWeightPounds, delta: -1.2)
        MeasurementBarSet(values: measurementValues)
        NutritionSummaryCard(plan: appState.nutritionPlan)
        BeforeAfterCard()
    }

    private var activityStats: [ProgressStat] {
        let workouts = appState.workoutLogs.count
        let hours = Double(workouts) * 0.8
        let totalSets = appState.workoutLogs.reduce(0) { $0 + $1.totalSets }
        let volume = totalSets * 85
        return [
            ProgressStat(title: "Number of Workouts", value: "\(workouts)", subtitle: "This range"),
            ProgressStat(title: "Hours at the Gym", value: String(format: "%.1f", hours), subtitle: "Approximate"),
            ProgressStat(title: "Total Weight Lifted (lb)", value: "\(volume)", subtitle: "Logged volume")
        ]
    }

    private var currentWeightPounds: Double {
        guard let kg = appState.activeProfile?.metrics.weightKg else { return 0 }
        return kg * 2.20462
    }

    private var measurementValues: [MeasurementValue] {
        [
            MeasurementValue(label: "Biceps", value: 19.3),
            MeasurementValue(label: "Abs", value: 32.1),
            MeasurementValue(label: "Waist", value: 31.0),
            MeasurementValue(label: "Chest", value: 42.0),
            MeasurementValue(label: "Shldrs", value: 47.5),
            MeasurementValue(label: "Thigh", value: 24.2),
            MeasurementValue(label: "Calf", value: 16.0)
        ]
    }
}

private enum ProgressMode: String, CaseIterable {
    case activity = "Activity"
    case body = "Body"
}

private enum ProgressRange: String, CaseIterable, Identifiable {
    case week = "1W", month = "1M", sixMonths = "6M", year = "1Y", all = "All"
    var id: String { rawValue }
}

private struct RangeChipRow: View {
    @Binding var selection: ProgressRange

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ProgressRange.allCases) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.rawValue)
                        .font(ZhymTypography.label(13, weight: .semibold))
                        .foregroundStyle(selection == range ? ZhymPalette.background : ZhymPalette.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule().fill(selection == range ? ZhymPalette.highlight : ZhymPalette.surface)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProgressSegmentedControl: View {
    @Binding var selection: ProgressMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProgressMode.allCases, id: \.rawValue) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.rawValue)
                        .font(ZhymTypography.label(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(selection == mode ? ZhymPalette.surface : Color.clear)
                        )
                        .foregroundStyle(selection == mode ? .white : ZhymPalette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.overlay))
    }
}

private struct ProgressStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
}

private struct ProgressStatRow: View {
    let stats: [ProgressStat]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.title)
                        .font(ZhymTypography.label(12))
                        .foregroundStyle(ZhymPalette.accent)
                    Text(stat.value)
                        .font(ZhymTypography.display(28))
                        .foregroundStyle(.white)
                    Text(stat.subtitle)
                        .font(ZhymTypography.label(12))
                        .foregroundStyle(ZhymPalette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(ZhymPalette.surface))
            }
        }
    }
}

private struct ProgressCalendarView: View {
    let logs: [WorkoutLog]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your workouts")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Text(monthTitle)
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(.white)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(calendarSlots()) { slot in
                    if let day = slot.day {
                        VStack {
                            Text("\(day)")
                                .font(ZhymTypography.label(12, weight: .semibold))
                                .foregroundStyle(day == today ? ZhymPalette.background : .white)
                        }
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            Circle().fill(completedDays.contains(day) ? ZhymPalette.highlight : (day == today ? ZhymPalette.blueAccent : ZhymPalette.surface))
                        )
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .zhymCard()
    }

    private struct CalendarSlot: Identifiable {
        let id = UUID()
        let day: Int?
    }

    private var today: Int {
        Calendar.current.component(.day, from: Date())
    }

    private var completedDays: Set<Int> {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        return Set(logs.compactMap { log in
            let comps = calendar.dateComponents([.day, .month, .year], from: log.completedAt)
            if comps.month == currentMonth && comps.year == currentYear {
                return comps.day
            }
            return nil
        })
    }

    private func calendarSlots() -> [CalendarSlot] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: Date()),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday + 6) % 7
        var slots: [CalendarSlot] = []
        for _ in 0..<leading {
            slots.append(CalendarSlot(day: nil))
        }
        slots.append(contentsOf: range.map { CalendarSlot(day: $0) })
        return slots
    }
}

private struct AchievementGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Button("More") {}
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.highlight)
            }
            HStack(spacing: 16) {
                AchievementCard(icon: "hands.sparkles", title: "Share", subtitle: "Celebrate streaks")
                AchievementCard(icon: "star.circle", title: "PR Alert", subtitle: "Back squat 242 lb")
            }
        }
    }
}

private struct AchievementCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(ZhymPalette.highlight)
            Text(title)
                .font(ZhymTypography.label(16, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.surface))
    }
}

private struct ExerciseGraphPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double

    static let sample: [ExerciseGraphPoint] = [
        ExerciseGraphPoint(label: "02/06", value: 120),
        ExerciseGraphPoint(label: "02/08", value: 140),
        ExerciseGraphPoint(label: "02/09", value: 160),
        ExerciseGraphPoint(label: "02/11", value: 210),
        ExerciseGraphPoint(label: "02/13", value: 242)
    ]
}

private struct ExerciseGraphCard: View {
    let points: [ExerciseGraphPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise graphs")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Button("Track exercise") {}
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.highlight)
            }
            GeometryReader { proxy in
                Path { path in
                    guard let first = points.first else { return }
                    let maxValue = (points.map(\.value).max() ?? 1)
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let step = width / CGFloat(max(points.count - 1, 1))
                    let startY = height - (CGFloat(first.value) / CGFloat(maxValue)) * height
                    path.move(to: CGPoint(x: 0, y: startY))
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * step
                        let y = height - (CGFloat(point.value) / CGFloat(maxValue)) * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(ZhymPalette.highlight, lineWidth: 3)
            }
            .frame(height: 140)

            HStack {
                ForEach(points) { point in
                    Text(point.label)
                        .font(ZhymTypography.label(11))
                        .foregroundStyle(ZhymPalette.accent)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .zhymCard()
    }
}

private struct MeasurementValue: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct MeasurementOverviewCard: View {
    let weight: Double
    let delta: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Measurements")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text(String(format: "%.1f lb", weight))
                .font(ZhymTypography.display(36))
                .foregroundStyle(.white)
            Text(String(format: "Change %.1f lb", delta))
                .font(ZhymTypography.label(13))
                .foregroundStyle(delta >= 0 ? ZhymPalette.success : ZhymPalette.warning)
        }
        .zhymCard()
    }
}

private struct MeasurementBarSet: View {
    let values: [MeasurementValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body detail")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(values) { entry in
                    VStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ZhymPalette.surface)
                            .frame(height: CGFloat(entry.value / (values.map(\.value).max() ?? 1)) * 100 + 20)
                            .overlay(
                                VStack {
                                    Text(String(format: "%.1f", entry.value))
                                        .font(ZhymTypography.label(11))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(6)
                            , alignment: .top)
                        Text(entry.label.uppercased())
                            .font(ZhymTypography.label(10))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .zhymCard()
    }
}

private struct NutritionSummaryCard: View {
    let plan: NutritionPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack(spacing: 24) {
                NutritionStat(icon: "leaf", title: "Calories", value: plan != nil ? "\(plan!.calories)" : "-")
                NutritionStat(icon: "figure.flexibility", title: "Protein", value: plan != nil ? "\(plan!.protein)" : "-")
            }
            Text("Targets calculated from your goals and data. Tap to share with a coach.")
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct NutritionStat: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(ZhymPalette.highlight)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(ZhymTypography.display(28))
                    .foregroundStyle(.white)
                Text(title)
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }
        }
    }
}

private struct BeforeAfterCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before and After")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ZhymPalette.surface)
                    .overlay(Text("Before").font(ZhymTypography.label(13)).foregroundStyle(ZhymPalette.accent))
                RoundedRectangle(cornerRadius: 16)
                    .fill(ZhymPalette.surface)
                    .overlay(Text("After").font(ZhymTypography.label(13)).foregroundStyle(ZhymPalette.accent))
            }
            .frame(height: 140)
            Text("Upload your first photo and start your transformation.")
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
            Button("Upload") {}
                .buttonStyle(.primaryZhym)
        }
        .zhymCard()
    }
}

private struct WorkoutHistoryView: View {
    let logs: [WorkoutLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout history")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            if logs.isEmpty {
                Text("Session logs will appear after you complete a workout.")
                    .font(ZhymTypography.label(15))
                    .foregroundStyle(ZhymPalette.accent)
            } else {
                ForEach(Array(logs.enumerated()), id: \.element.id) { pair in
                    let index = pair.offset
                    let log = pair.element
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.sessionName)
                                .font(ZhymTypography.label(18))
                                .foregroundStyle(.white)
                            Text("\(log.focus)")
                                .font(ZhymTypography.label(14))
                                .foregroundStyle(ZhymPalette.accent)
                            Text("Sets: \(log.totalSets)")
                                .font(ZhymTypography.label(13))
                                .foregroundStyle(ZhymPalette.accent)
                        }
                        Spacer()
                        Text(relativeString(log.completedAt))
                            .font(ZhymTypography.label(13))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    .padding(.vertical, 6)
                    if index < logs.count - 1 {
                        Divider().background(ZhymPalette.graphite)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.graphite))
    }
}

private struct SetCompletionCard: View {
    let completed: Int
    let target: Int

    private var completionRate: Double {
        guard target > 0 else { return 0 }
        return min(Double(completed) / Double(target), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sets closed this week")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(completed)")
                    .font(ZhymTypography.display(36))
                    .foregroundStyle(.white)
                Text("of \(target)")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
            }
            ProgressView(value: completionRate)
                .tint(ZhymPalette.platinum)
        }
        .zhymCard()
    }
}

private struct WeeklyAdaptationCard: View {
    let adjustment: WeeklyAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly adaptation")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text(adjustment.notes)
                .font(ZhymTypography.label(16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Volume \(adjustment.volumeChangePercent)% · Calories \(adjustment.calorieAdjustment >= 0 ? "+" : "")\(adjustment.calorieAdjustment)")
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct HealthEducationStack: View {
    private let topics = HealthEducationTopic.demoTopics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery intelligence")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            ForEach(topics) { topic in
                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(.white)
                    Text(topic.description)
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 18).fill(ZhymPalette.graphite))
            }
        }
    }
}

// MARK: - PROFILE

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeSetting: SettingAction?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                PromoCard()

                if let profile = appState.activeProfile {
                    ProfileDetailCard(profile: profile)
                }

                SettingGroup(title: "Account") {
                    SettingRowView(icon: "crown.fill", title: "My Subscription", subtitle: "Zhym Pro", actionText: "Manage", action: {
                        activeSetting = .subscription
                    })
                    Divider().background(ZhymPalette.overlay)
                    SettingRowView(icon: "bolt.fill", title: "Experience Level", subtitle: appState.activeProfile?.metrics.experience.rawValue ?? "Set level", action: {
                        activeSetting = .experience
                    })
                }

                SettingGroup(title: "Preferences") {
                    SettingRowView(icon: "ruler", title: "Units of Measurement", subtitle: "Metric", action: {
                        activeSetting = .units
                    })
                    Divider().background(ZhymPalette.overlay)
                    SmartToggleRow(title: "Smart Weight & Reps")
                }

                Button("Recalibrate system") {
                    withAnimation(.easeInOut) {
                        appState.resetProfile()
                    }
                }
                .buttonStyle(.secondaryZhym)
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [ZhymPalette.night, ZhymPalette.wine.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .sheet(item: $activeSetting) { selection in
            SettingDetailSheet(action: selection)
        }
    }
}

private enum SettingAction: String, Identifiable {
    case subscription, experience, units
    var id: String { rawValue }
    var title: String {
        switch self {
        case .subscription: return "Subscription"
        case .experience: return "Experience Level"
        case .units: return "Units of Measurement"
        }
    }
}

private struct PromoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7 Days On Us")
                .font(ZhymTypography.label(14, weight: .semibold))
                .foregroundStyle(.white)
            Text("ZHYM PRO")
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)
            Text("Unlock premium programming, weekly coaching, and benchmarking tools.")
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(red: 0.2, green: 0.4, blue: 0.9), Color(red: 0.1, green: 0.2, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(28)
    }
}

private struct ProfileDetailCard: View {
    let profile: ZhymUserProfile

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(ZhymPalette.surface)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(profile.trainingPreferences.objective.rawValue.prefix(1))
                        .font(ZhymTypography.display(28))
                        .foregroundStyle(ZhymPalette.highlight)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Athlete")
                    .font(ZhymTypography.label(18, weight: .semibold))
                    .foregroundStyle(.white)
                Text("My Profile")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(ZhymPalette.accent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(ZhymPalette.surface))
    }
}

private struct SettingGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(ZhymTypography.label(12))
                .foregroundStyle(ZhymPalette.accent)
            VStack(spacing: 0) {
                content
            }
            .background(RoundedRectangle(cornerRadius: 24).fill(ZhymPalette.surface))
        }
    }
}

private struct SettingRowView: View {
    let icon: String
    let title: String
    let subtitle: String?
    var actionText: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ZhymPalette.overlay)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(ZhymPalette.highlight)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ZhymTypography.label(16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(ZhymTypography.label(13))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                }
                Spacer()
                if let actionText {
                    Text(actionText)
                        .font(ZhymTypography.label(13, weight: .semibold))
                        .foregroundStyle(ZhymPalette.highlight)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(ZhymPalette.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SmartToggleRow: View {
    let title: String
    @State private var isOn = true

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ZhymPalette.overlay)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "lightbulb.fill").foregroundStyle(ZhymPalette.highlight))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ZhymTypography.label(16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Auto-suggests load progressions")
                        .font(ZhymTypography.label(13))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: ZhymPalette.highlight))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct SettingDetailSheet: View {
    let action: SettingAction

    var body: some View {
        VStack(spacing: 16) {
            Text(action.title)
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)
            Text("Detailed controls for \(action.title.lowercased()) will arrive soon. Tap manage to continue inside Zhym.")
                .font(ZhymTypography.label(15))
                .foregroundStyle(ZhymPalette.accent)
                .multilineTextAlignment(.center)
            Button("Close") {}
                .buttonStyle(.primaryZhym)
        }
        .padding(32)
        .background(ZhymPalette.background.ignoresSafeArea())
    }
}

private let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

private func relativeString(_ date: Date) -> String {
    relativeFormatter.localizedString(for: date, relativeTo: Date())
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct HealthEducationTopic: Identifiable {
    let id = UUID()
    let title: String
    let description: String

    static let demoTopics: [HealthEducationTopic] = [
        HealthEducationTopic(title: "Progressive overload stays gradual", description: "Volume increases are capped at 10-15% weekly to protect joints and keep youth athletes safe."),
        HealthEducationTopic(title: "Sleep funds adaptation", description: "Sleep quality below 6/10 triggers recovery emphasis so tissue repair stays ahead of training."),
        HealthEducationTopic(title: "Protein supports growth", description: "Protein targets are set first to sustain muscle and hormone health even in Access Mode."),
        HealthEducationTopic(title: "Rest prevents injury", description: "Deload weeks auto-inserted every 4th week or sooner when check-ins flag fatigue.")
    ]
}

private let dayLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "E"
    return formatter
}()


private func sessionCounts(for logs: [WorkoutLog]) -> [(label: String, value: Double)] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<7).reversed().map { offset in
        let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let label = dayLabelFormatter.string(from: day)
        let count = Double(logs.filter { calendar.isDate($0.completedAt, inSameDayAs: day) }.count)
        return (label, count)
    }
}

private func setsCompletedThisWeek(logs: [WorkoutLog]) -> Int {
    let calendar = Calendar.current
    let currentComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
    return logs.reduce(0) { partial, log in
        let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: log.completedAt)
        if components.weekOfYear == currentComponents.weekOfYear && components.yearForWeekOfYear == currentComponents.yearForWeekOfYear {
            return partial + log.totalSets
        }
        return partial
    }
}

private func targetSets(for plan: TrainingPlan?) -> Int {
    guard let sessions = plan?.sessions else { return 0 }
    return sessions.flatMap(\.exercises).map(\.sets).reduce(0, +)
}

#Preview {
    let metrics = UserMetrics(heightCm: 180, weightKg: 82, experience: .advanced)
    let constraints = ConstraintSummary(sessionsPerWeek: 5, equipment: .gym, dietaryRule: .none, accessMode: .standard)
    let preferences = TrainingPreferences(objective: .strength, constraints: constraints, isYouthAthlete: false)
    let profile = ZhymUserProfile(metrics: metrics, preferences: preferences)
    let appState = AppState()
    appState.configureProfile(profile)
    return MainExperienceView()
        .environmentObject(appState)
}
