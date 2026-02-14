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

    private var plan: TrainingPlan? { appState.trainingPlan }
    private var session: WorkoutSession? { plan?.sessions[safe: appState.activeSessionIndex] }
    private var profile: ZhymUserProfile? { appState.activeProfile }

    private var stats: [SessionStat] {
        guard let session else { return [] }
        return SessionStat.make(for: session, profile: profile)
    }

    private var timelineEntries: [TimelineEntry] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            if calendar.isDateInToday(date) {
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
            VStack(alignment: .leading, spacing: 24) {
                WorkoutToolbar(profileName: profile?.trainingPreferences.objective.rawValue ?? "Adaptive Plan")

                DayTimelineView(entries: timelineEntries)

                PlanOverviewCard(plan: plan, session: session, profile: profile, lastLog: appState.workoutLogs.first) {
                    if let exercise = session?.exercises.first {
                        activeGuide = GuidanceLibrary.guide(for: exercise.name)
                    }
                }

                if !stats.isEmpty {
                    SessionStatRow(stats: stats)
                }

                if session != nil {
                    WarmupCard {
                        activeGuide = GuidanceLibrary.guide(for: "General Warmup")
                    }
                }

                if let session {
                    ExerciseStack(session: session, viewGuide: { exercise in
                        activeGuide = GuidanceLibrary.guide(for: exercise.name)
                    }, startWorkout: {
                        onBeginSession()
                    })
                } else {
                    EmptySessionPlaceholder()
                }

                ConsistencyCard(score: appState.disciplineScore, fatigueNotice: appState.fatigueAdvisory) {
                    showingCheckIn = true
                }

                if let plan = appState.nutritionPlan {
                    NutritionPulseCard(plan: plan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(ZhymPalette.background.ignoresSafeArea())
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideSheet(guide: guide)
        }
        .sheet(isPresented: $showingCheckIn) {
            DisciplineCheckInSheet()
                .environmentObject(appState)
        }
    }
}

private struct WorkoutToolbar: View {
    var profileName: String

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
                ToolbarIconButton(systemName: "gift.fill", highlight: true)
                ToolbarIconButton(systemName: "calendar")
                ToolbarIconButton(systemName: "slider.horizontal.3")
            }
        }
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    var highlight: Bool = false

    var body: some View {
        Button(action: {}) {
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
            return ZhymPalette.blueAccent
        case .today:
            return ZhymPalette.highlight
        case .upcoming:
            return ZhymPalette.blueAccent.opacity(0.8)
        case .rest:
            return ZhymPalette.accent
        }
    }
}

private struct DayTimelineView: View {
    let entries: [TimelineEntry]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(entries) { entry in
                VStack(spacing: 6) {
                    Text(dayLabelFormatter.string(from: entry.date).uppercased())
                        .font(ZhymTypography.label(12, weight: entry.status == .today ? .semibold : .regular))
                        .foregroundStyle(entry.status == .today ? .white : ZhymPalette.accent)
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
                        .fill(entry.status == .today ? ZhymPalette.overlay : ZhymPalette.surface)
                )
            }
        }
    }

    private func dayNumber(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: "%02d", day)
    }
}

private struct PlanOverviewCard: View {
    let plan: TrainingPlan?
    let session: WorkoutSession?
    let profile: ZhymUserProfile?
    let lastLog: WorkoutLog?
    let openGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(weekSubtitle)
                        .font(ZhymTypography.label(13))
                        .foregroundStyle(ZhymPalette.accent)
                    Text("TODAY'S WORKOUT")
                        .font(ZhymTypography.label(18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(session?.focus ?? "Recovery emphasis")
                        .font(ZhymTypography.display(26))
                        .foregroundStyle(ZhymPalette.highlight)
                }
                Spacer()
                Button(action: openGuide) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ZhymPalette.highlight)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ZhymPalette.overlay))
                }
            }

            if let plan {
                HStack(spacing: 12) {
                    Text("Split: \(plan.split.rawValue)")
                    Text("Sessions: \(plan.sessions.count)/wk")
                }
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            } else {
                Text("Generate a plan to unlock personalized training and fuel guidance.")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
            }

            if let log = lastLog {
                Text("Last: \(log.sessionName) · \(relativeString(log.completedAt))")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }
        }
        .zhymCard()
    }

    private var weekSubtitle: String {
        guard let plan, let profile else { return "Week • Foundations" }
        let phase: String
        switch profile.trainingPreferences.objective {
        case .muscle: phase = "Hypertrophy"
        case .fatLoss: phase = "Recomp"
        case .strength: phase = "Foundations"
        case .balance: phase = "Performance"
        }
        return "Week \(plan.week)/5 · \(phase)"
    }
}

private struct SessionStatRow: View {
    let stats: [SessionStat]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: stat.icon)
                        .foregroundStyle(ZhymPalette.highlight)
                    Text(stat.value)
                        .font(ZhymTypography.display(26))
                        .foregroundStyle(.white)
                    Text(stat.label)
                        .font(ZhymTypography.label(13))
                        .foregroundStyle(ZhymPalette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(ZhymPalette.surface))
            }
        }
    }
}

private struct SessionStat: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String

    static func make(for session: WorkoutSession, profile: ZhymUserProfile?) -> [SessionStat] {
        let exerciseCount = session.exercises.count
        let duration = estimatedDuration(for: session)
        let calories = estimatedCalories(for: session, profile: profile)
        return [
            SessionStat(icon: "bolt.fill", value: "\(exerciseCount)", label: "Exercises"),
            SessionStat(icon: "clock.fill", value: "\(duration) min", label: "Duration"),
            SessionStat(icon: "flame.fill", value: "\(calories) cal", label: "Energy")
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

private struct WarmupCard: View {
    let openGuide: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(ZhymPalette.overlay)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "figure.cooldown")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(ZhymPalette.highlight)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("General Warmup")
                    .font(ZhymTypography.label(16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("6 min mobility, 90s bike")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }
            Spacer()
            Button(action: openGuide) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(ZhymPalette.accent)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.surface))
    }
}

private struct ExerciseStack: View {
    let session: WorkoutSession
    let viewGuide: (ExercisePrescription) -> Void
    let startWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { pair in
                if pair.offset == 0 {
                    ExerciseHeroCard(exercise: pair.element, viewGuide: viewGuide)
                } else {
                    ExerciseTile(exercise: pair.element, viewGuide: viewGuide)
                }
            }

            Button("Start Workout") {
                startWorkout()
            }
            .buttonStyle(.primaryZhym)
        }
    }
}

private struct ExerciseHeroCard: View {
    let exercise: ExercisePrescription
    let viewGuide: (ExercisePrescription) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(colors: [ZhymPalette.blueAccent, ZhymPalette.overlay], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: 220)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(ZhymTypography.display(30))
                                .foregroundStyle(.white)
                            Text(exercise.intent)
                                .font(ZhymTypography.label(14))
                                .foregroundStyle(ZhymPalette.accent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: .bottomLeading)
                    )
                Button(action: { viewGuide(exercise) }) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Circle().fill(ZhymPalette.highlight.opacity(0.35)))
                        .padding(12)
                }
            }

            HStack {
                Text("\(exercise.sets) sets · \(exercise.reps)")
                    .font(ZhymTypography.label(15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    viewGuide(exercise)
                } label: {
                    Label("Guide", systemImage: "info.circle")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.highlight)
                }
            }
        }
        .zhymCard()
    }
}

private struct ExerciseTile: View {
    let exercise: ExercisePrescription
    let viewGuide: (ExercisePrescription) -> Void

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(ZhymPalette.overlay)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "figure.strengthtraining.functional")
                        .font(.system(size: 28))
                        .foregroundStyle(ZhymPalette.highlight)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(ZhymTypography.label(16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(exercise.sets)x \(exercise.reps) · \(exercise.intent)")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }
            Spacer()
            Button(action: { viewGuide(exercise) }) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(ZhymPalette.accent)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.surface))
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
            Text("Train")
                .font(ZhymTypography.display(44))
                .foregroundStyle(.white)

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
        .background(ZhymPalette.charcoal.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exercises")
                            .font(ZhymTypography.display(38))
                            .foregroundStyle(.white)
                        Text("Browse 200+ guided movements with form cues and swaps.")
                            .font(ZhymTypography.label(15))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    Spacer()
                    Button("Start smart session") {
                        startSession()
                    }
                    .buttonStyle(.secondaryZhym)
                }

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ZhymPalette.accent)
                    TextField("Search movements", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(ZhymPalette.surface))

                FilterMenus(selectedEquipment: $selectedEquipment, selectedMuscle: $selectedMuscle, selectedLevel: $selectedLevel)

                ForEach(filteredExercises) { exercise in
                    ExerciseLibraryCard(exercise: exercise) {
                        activeGuide = GuidanceLibrary.guide(for: exercise.name)
                    }
                }
            }
            .padding(24)
        }
        .background(ZhymPalette.background.ignoresSafeArea())
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

    private var filteredPrograms: [ProgramLibraryItem] {
        ProgramLibraryItem.demo.filter { item in
            (selectedEquipment == .all || item.equipment == selectedEquipment) &&
            (selectedMuscle == .all || item.focus == selectedMuscle) &&
            (selectedDuration == .all || item.days == selectedDuration)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Library")
                            .font(ZhymTypography.display(38))
                            .foregroundStyle(.white)
                        Text("Plug-and-play programs curated by Zhym coaches.")
                            .font(ZhymTypography.label(15))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    Spacer()
                    Label("Premium", systemImage: "crown.fill")
                        .font(ZhymTypography.label(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(ZhymPalette.overlay))
                        .foregroundStyle(ZhymPalette.highlight)
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
                    ProgramLibraryCard(program: program)
                }
            }
            .padding(24)
        }
        .background(ZhymPalette.background.ignoresSafeArea())
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

            Button("Preview cycle") {}
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

// MARK: - PROGRESS

struct ProgressScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: ProgressMode = .activity
    @State private var range: ProgressRange = .all

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
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
                NutritionStat(icon: "leaf", title: "Calories", value: plan != nil ? "\(plan!.calories)" : "—")
                NutritionStat(icon: "figure.flexibility", title: "Protein", value: plan != nil ? "\(plan!.protein)" : "—")
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                PromoCard()

                if let profile = appState.activeProfile {
                    ProfileDetailCard(profile: profile)
                }

                SettingGroup(title: "Account") {
                    SettingRowView(icon: "crown.fill", title: "My Subscription", subtitle: "Zhym Pro", actionText: "Manage")
                    Divider().background(ZhymPalette.overlay)
                    SettingRowView(icon: "bolt.fill", title: "Experience Level", subtitle: appState.activeProfile?.metrics.experience.rawValue ?? "Set level")
                }

                SettingGroup(title: "Preferences") {
                    SettingRowView(icon: "ruler", title: "Units of Measurement", subtitle: "Metric")
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
        .background(ZhymPalette.background.ignoresSafeArea())
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

    var body: some View {
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
        HealthEducationTopic(title: "Progressive overload stays gradual", description: "Volume increases are capped at 10–15% weekly to protect joints and keep youth athletes safe."),
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
