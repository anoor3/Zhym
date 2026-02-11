import SwiftUI
import UIKit

private enum RootTab: String, CaseIterable, Identifiable {
    case today, train, fuel, progress, profile

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "circle.grid.2x2"
        case .train: return "figure.strengthtraining.traditional"
        case .fuel: return "drop"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .profile: return "seal"
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

struct MainExperienceView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: RootTab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayScreen(onBeginSession: {
                withAnimation(.easeInOut) {
                    selection = .train
                }
            })
                .tabItem { Label("Today", systemImage: RootTab.today.icon) }
                .tag(RootTab.today)

            TrainScreen()
                .tabItem { Label("Train", systemImage: RootTab.train.icon) }
                .tag(RootTab.train)

            FuelScreen()
                .tabItem { Label("Fuel", systemImage: RootTab.fuel.icon) }
                .tag(RootTab.fuel)

            ProgressScreen()
                .tabItem { Label("Progress", systemImage: RootTab.progress.icon) }
                .tag(RootTab.progress)

            ProfileScreen()
                .tabItem { Label("Profile", systemImage: RootTab.profile.icon) }
                .tag(RootTab.profile)
        }
        .preferredColorScheme(.dark)
        .accentColor(ZhymPalette.platinum)
    }
}

// MARK: - TODAY

struct TodayScreen: View {
    @EnvironmentObject private var appState: AppState
    let onBeginSession: () -> Void
    @State private var activeGuide: ExerciseGuide?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Today")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                TodayCard(
                    session: appState.trainingPlan?.sessions[safe: appState.activeSessionIndex],
                    nutrition: appState.nutritionPlan,
                    adjustment: appState.weeklyAdjustment,
                    lastLog: appState.workoutLogs.first,
                    beginSession: onBeginSession,
                    viewGuide: { guide in
                        activeGuide = guide
                    }
                )

                if let plan = appState.nutritionPlan {
                    CalorieStatusCard(plan: plan)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Recovery Snapshot")
                        .font(ZhymTypography.label(15))
                        .foregroundStyle(ZhymPalette.accent)
                    RecoveryBlock(title: "Nervous system", value: "Ready", detail: "+3% from last week")
                    RecoveryBlock(title: "Sleep debt", value: "Low", detail: "6h 50m avg")
                }
            }
            .padding(24)
        }
        .background(ZhymPalette.charcoal.ignoresSafeArea())
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideSheet(guide: guide)
        }
    }
}

private struct TodayCard: View {
    let session: WorkoutSession?
    let nutrition: NutritionPlan?
    let adjustment: WeeklyAdjustment?
    let lastLog: WorkoutLog?
    let beginSession: () -> Void
    let viewGuide: (ExerciseGuide) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session {
                Text(session.name)
                    .font(ZhymTypography.display(30))
                    .foregroundStyle(.white)
                Text(session.focus)
                    .font(ZhymTypography.label(15))
                    .foregroundStyle(ZhymPalette.accent)
            } else {
                Text("Rest + Mobilize")
                    .font(ZhymTypography.display(30))
                    .foregroundStyle(.white)
                Text("Stay light. Walk. Hydrate.")
                    .font(ZhymTypography.label(15))
                    .foregroundStyle(ZhymPalette.accent)
            }

            HStack(spacing: 18) {
                if let calories = nutrition?.calories {
                    MetricBlock(label: "Calories", value: "\(calories)")
                }
                let statusLabel = session == nil ? "Rest" : "Active"
                MetricBlock(label: "Status", value: statusLabel)
            }

            if let adjustment {
                Text("Plan updated: Week \(adjustment.weekNumber) • Volume \(adjustment.volumeChangePercent)% • Calories \(adjustment.calorieAdjustment >= 0 ? "+" : "")\(adjustment.calorieAdjustment)")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }

            if let log = lastLog {
                Text("Last session \(relativeString(log.completedAt)) — \(log.sessionName)")
                    .font(ZhymTypography.label(13))
                    .foregroundStyle(ZhymPalette.accent)
            }

            if session == nil {
                Button("View recovery protocol") {}
                    .buttonStyle(.primaryZhym)
            } else {
                Button("Begin session") {
                    beginSession()
                }
                .buttonStyle(.primaryZhym)

                if let exercise = session?.exercises.first {
                    Button("Technique brief") {
                        let guide = GuidanceLibrary.guide(for: exercise.name)
                        viewGuide(guide)
                    }
                    .buttonStyle(.secondaryZhym)
                }
            }
        }
        .zhymCard()
    }
}

private struct MetricBlock: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(ZhymTypography.label(11))
                .foregroundColor(ZhymPalette.accent)
                .tracking(1.2)
            Text(value)
                .font(ZhymTypography.numeric(30))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecoveryBlock: View {
    let title: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ZhymTypography.label(12))
                .foregroundStyle(ZhymPalette.accent)
            Text(value)
                .font(ZhymTypography.display(26))
                .foregroundStyle(.white)
            Text(detail)
                .font(ZhymTypography.label(13))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct WeeklyAdaptationCard: View {
    let adjustment: WeeklyAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly adaptation")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text(adjustment.notes)
                .font(ZhymTypography.display(26))
                .foregroundStyle(.white)
            Text("Volume \(adjustment.volumeChangePercent)% • Calories \(adjustment.calorieAdjustment >= 0 ? "+" : "")\(adjustment.calorieAdjustment)")
                .font(ZhymTypography.label(15))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

private struct CalorieStatusCard: View {
    let plan: NutritionPlan

    private var dayProgress: Double {
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        return min(max(hour / 24, 0.2), 0.95)
    }

    private var consumed: Int { Int(Double(plan.calories) * dayProgress) }
    private var remaining: Int { max(plan.calories - consumed, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition status")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text("\(consumed) / \(plan.calories) kcal")
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)
            ProgressView(value: dayProgress)
                .tint(ZhymPalette.platinum)
            HStack {
                MetricBlock(label: "Protein", value: "\(plan.protein) g")
                MetricBlock(label: "Carbs", value: "\(plan.carbs) g")
                MetricBlock(label: "Fats", value: "\(plan.fats) g")
            }
            Text("Estimated remaining: \(remaining) kcal")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
        }
        .zhymCard()
    }
}

// MARK: - TRAIN

struct TrainScreen: View {
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

// MARK: - FUEL

struct FuelScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Fuel")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                if let nutrition = appState.nutritionPlan {
                    MacroRingSet(macros: macroStatus(from: nutrition))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Meals")
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                    if let meals = appState.nutritionPlan?.meals {
                        ForEach(meals) { meal in
                            MealRow(meal: meal)
                        }
                    } else {
                        Text("Nutrition plan pending onboarding.")
                            .font(ZhymTypography.label(15))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                }
            }
            .padding(24)
        }
        .background(ZhymPalette.charcoal.ignoresSafeArea())
    }

    private func macroStatus(from plan: NutritionPlan) -> [MacroMetric] {
        [
            MacroMetric(label: "Protein", value: Double(plan.protein) * 0.65, target: Double(plan.protein), color: ZhymPalette.platinum),
            MacroMetric(label: "Carbs", value: Double(plan.carbs) * 0.55, target: Double(plan.carbs), color: ZhymPalette.accent),
            MacroMetric(label: "Fats", value: Double(plan.fats) * 0.5, target: Double(plan.fats), color: ZhymPalette.success)
        ]
    }
}

private struct MacroMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let target: Double
    let color: Color
}

private struct MacroRingSet: View {
    let macros: [MacroMetric]
    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            ForEach(macros) { macro in
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(ZhymPalette.graphite, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: min(1, macro.value / macro.target))
                            .stroke(macro.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 80, height: 80)

                    Text(macro.label)
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    Text("\(Int(macro.value))/\(Int(macro.target)) g")
                        .font(ZhymTypography.numeric(20))
                        .foregroundStyle(.white)
                    Button("Swap suggestion") {}
                        .buttonStyle(.secondaryZhym)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .zhymCard()
    }
}

private struct MealRow: View {
    let meal: Meal
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title.uppercased())
                    .font(ZhymTypography.label(12))
                    .foregroundStyle(ZhymPalette.accent)
                Text(meal.description)
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(ZhymPalette.platinum)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(ZhymPalette.graphite))
    }
}

// MARK: - PROGRESS

struct ProgressScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Progress")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly training density")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                    SessionHistoryChart(data: sessionCounts(for: appState.workoutLogs))
                        .zhymCard()
                }

                SetCompletionCard(
                    completed: setsCompletedThisWeek(logs: appState.workoutLogs),
                    target: targetSets(for: appState.trainingPlan)
                )

                if let plan = appState.trainingPlan {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Training split")
                            .font(ZhymTypography.label(14))
                            .foregroundStyle(ZhymPalette.accent)
                        ForEach(plan.sessions) { session in
                            HStack {
                                Text(session.name)
                                    .font(ZhymTypography.label(18))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(session.focus)
                                    .font(ZhymTypography.label(14))
                                    .foregroundStyle(ZhymPalette.accent)
                            }
                            .padding(.vertical, 6)
                        }
                        Divider()
                            .background(ZhymPalette.graphite)
                        Text("Week \(plan.week) • Split: \(plan.split.rawValue)")
                            .font(ZhymTypography.label(14))
                            .foregroundStyle(ZhymPalette.accent)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 22).fill(ZhymPalette.graphite))
                }

                if let adjustment = appState.weeklyAdjustment {
                    WeeklyAdaptationCard(adjustment: adjustment)
                }

                WorkoutHistoryView(logs: appState.workoutLogs)
            }
            .padding(24)
        }
        .background(ZhymPalette.charcoal.ignoresSafeArea())
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

private struct SessionHistoryChart: View {
    let data: [(label: String, value: Double)]

    var body: some View {
        let maxValue = max(data.map(\.value).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(data, id: \.label) { entry in
                VStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(entry.value > 0 ? ZhymPalette.platinum : ZhymPalette.graphite)
                        .frame(height: CGFloat(entry.value / maxValue) * 120)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Text(entry.label)
                        .font(ZhymTypography.label(12))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }
        }
        .padding(.vertical, 16)
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

// MARK: - PROFILE

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Profile")
                    .font(ZhymTypography.display(44))
                    .foregroundStyle(.white)

                if let profile = appState.activeProfile {
                    ProfileSummary(profile: profile)
                }

                if let plan = appState.trainingPlan {
                    PlanDetailSummary(plan: plan)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weekly rhythm")
                            .font(ZhymTypography.label(14))
                            .foregroundStyle(ZhymPalette.accent)
                        SessionHistoryChart(data: sessionCounts(for: appState.workoutLogs))
                    }
                    .zhymCard()
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
        .background(ZhymPalette.charcoal.ignoresSafeArea())
    }
}

private struct ProfileSummary: View {
    let profile: ZhymUserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Intent")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text(profile.trainingPreferences.objective.rawValue)
                .font(ZhymTypography.display(32))
                .foregroundStyle(.white)

            Divider().background(ZhymPalette.graphite)

            VStack(alignment: .leading, spacing: 8) {
                Text("Baseline")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Text("Height: \(Int(profile.metrics.heightCm)) cm")
                Text("Weight: \(Int(profile.metrics.weightKg)) kg")
                Text(profile.metrics.experience.rawValue)
            }
            .font(ZhymTypography.label(16))
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Constraints")
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
                Text("Sessions: \(profile.trainingPreferences.constraints.sessionsPerWeek)/week")
                Text(profile.trainingPreferences.constraints.equipment.rawValue)
                Text("Diet: \(profile.trainingPreferences.constraints.dietaryRule.rawValue)")
            }
            .font(ZhymTypography.label(16))
            .foregroundStyle(.white)
        }
        .zhymCard()
    }
}

private struct PlanDetailSummary: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current plan")
                .font(ZhymTypography.label(14))
                .foregroundStyle(ZhymPalette.accent)
            Text("Week \(plan.week)")
                .font(ZhymTypography.display(30))
                .foregroundStyle(.white)
            Text(plan.split.rawValue)
                .font(ZhymTypography.label(18))
                .foregroundStyle(ZhymPalette.accent)

            Divider().background(ZhymPalette.graphite)

            ForEach(plan.sessions) { session in
                HStack {
                    Text(session.name)
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(session.exercises.count) exercises")
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                }
                .padding(.vertical, 4)
            }
        }
        .zhymCard()
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

private let dayLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "E"
    return formatter
}()

private func sessionCounts(for logs: [WorkoutLog]) -> [(label: String, value: Double)] {
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    return (0..<7).reversed().map { offset in
        let day = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
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
    let constraints = ConstraintSummary(sessionsPerWeek: 5, equipment: .gym, dietaryRule: .none)
    let preferences = TrainingPreferences(objective: .strength, constraints: constraints)
    let profile = ZhymUserProfile(metrics: metrics, preferences: preferences)
    let appState = AppState()
    appState.configureProfile(profile)
    return MainExperienceView()
        .environmentObject(appState)
}
