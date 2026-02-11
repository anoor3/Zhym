import Foundation

enum TrainingExperience: String, CaseIterable, Identifiable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

enum TrainingObjective: String, CaseIterable, Identifiable, Codable {
    case muscle = "Muscle Gain"
    case fatLoss = "Fat Reduction"
    case strength = "Strength Dominance"
    case balance = "Balanced Performance"

    var id: String { rawValue }
}

enum TrainingConstraint: String, Identifiable, CaseIterable, Codable {
    case gym = "Gym"
    case home = "Home"
    case mixed = "Mixed"

    var id: String { rawValue }
}

enum DietaryRule: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case vegetarian = "Vegetarian"
    case halal = "Halal"
    case custom = "Custom"

    var id: String { rawValue }
}

enum AccessMode: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"
    case access = "Access Mode"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard:
            return "Full gym or mixed equipment"
        case .access:
            return "Bodyweight + small space"
        }
    }
}

struct UserMetrics: Codable {
    var heightCm: Double
    var weightKg: Double
    var experience: TrainingExperience
}

struct TrainingPreferences: Codable {
    var objective: TrainingObjective
    var constraints: ConstraintSummary
    var isYouthAthlete: Bool
}

struct ConstraintSummary: Codable {
    var sessionsPerWeek: Int
    var equipment: TrainingConstraint
    var dietaryRule: DietaryRule
    var accessMode: AccessMode
}

struct ZhymUserProfile: Identifiable, Codable {
    let id: UUID
    var metrics: UserMetrics
    var trainingPreferences: TrainingPreferences
    var createdAt: Date

    init(metrics: UserMetrics, preferences: TrainingPreferences) {
        self.id = UUID()
        self.metrics = metrics
        self.trainingPreferences = preferences
        self.createdAt = .now
    }
}

final class AppState: ObservableObject {
    @Published var activeProfile: ZhymUserProfile?
    @Published var currentDaySummary: DaySummary = .placeholder
    @Published var trainingPlan: TrainingPlan?
    @Published var nutritionPlan: NutritionPlan?
    @Published var weeklyAdjustment: WeeklyAdjustment?
    @Published var workoutLogs: [WorkoutLog] = []
    @Published var activeSessionIndex: Int = 0
    @Published var disciplineEntries: [DisciplineEntry] = []
    @Published var disciplineScore: Int = 0
    @Published var fatigueAdvisory: String?
    private let planRepository = PlanRepository()
    private let storageKey = "zhym.profile"

    var isOnboarded: Bool { activeProfile != nil }

    init() {
        if let storedProfile = loadProfile() {
            applyProfile(storedProfile)
        }
    }

    func configureProfile(_ profile: ZhymUserProfile) {
        applyProfile(profile)
        persistProfile(profile)
    }

    func resetProfile() {
        activeProfile = nil
        trainingPlan = nil
        nutritionPlan = nil
        weeklyAdjustment = nil
        currentDaySummary = .placeholder
        workoutLogs.removeAll()
        activeSessionIndex = 0
        disciplineEntries.removeAll()
        disciplineScore = 0
        fatigueAdvisory = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func recordWorkout(session: WorkoutSession) {
        let totalSets = session.exercises.map { $0.sets }.reduce(0, +)
        let log = WorkoutLog(sessionName: session.name, focus: session.focus, completedAt: Date(), totalExercises: session.exercises.count, totalSets: totalSets)
        workoutLogs.insert(log, at: 0)
        if workoutLogs.count > 20 {
            workoutLogs.removeLast()
        }
        updateFatigueAdvisory()
    }

    func recordDisciplineEntry(completedTraining: Bool, energyLevel: Int, sleepQuality: Int, stressLevel: Int) {
        let entry = DisciplineEntry(date: Date(), completedTraining: completedTraining, energyLevel: energyLevel, sleepQuality: sleepQuality, stressLevel: stressLevel)
        disciplineEntries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
        disciplineEntries.append(entry)
        updateDisciplineScore()
        updateFatigueAdvisory()
    }

    private func applyProfile(_ profile: ZhymUserProfile) {
        let payload = planRepository.bootstrapPlans(for: profile)
        activeProfile = profile
        trainingPlan = payload.0
        nutritionPlan = payload.1
        weeklyAdjustment = payload.2
        activeSessionIndex = 0
        disciplineEntries.removeAll()
        disciplineScore = 0
        currentDaySummary = DaySummary(
            workoutTitle: payload.0.sessions.first?.name ?? "Rest",
            caloriesRemaining: payload.1.calories,
            isRestDay: payload.0.sessions.isEmpty
        )
        updateFatigueAdvisory()
    }

    private func persistProfile(_ profile: ZhymUserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadProfile() -> ZhymUserProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ZhymUserProfile.self, from: data)
    }

    private func updateDisciplineScore() {
        guard !disciplineEntries.isEmpty else {
            disciplineScore = 0
            return
        }
        let recent = disciplineEntries.filter { entry in
            guard let days = Calendar.current.dateComponents([.day], from: entry.date, to: Date()).day else { return false }
            return days < 7
        }
        guard !recent.isEmpty else {
            disciplineScore = 0
            return
        }
        let completionPoints = recent.reduce(0) { partial, entry in
            partial + (entry.completedTraining ? 3 : 0) + entry.energyLevel + entry.sleepQuality - entry.stressLevel
        }
        disciplineScore = max(0, min(100, completionPoints / recent.count))
    }

    private func updateFatigueAdvisory() {
        guard let profile = activeProfile else {
            fatigueAdvisory = nil
            return
        }
        let calendar = Calendar.current
        let consecutiveMisses = (0..<3).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return false }
            return !workoutLogs.contains { calendar.isDate($0.completedAt, inSameDayAs: day) }
        }
        let lowEntries = disciplineEntries.suffix(3).filter { $0.energyLevel <= 4 || $0.sleepQuality <= 4 || $0.stressLevel >= 7 }
        if consecutiveMisses || !lowEntries.isEmpty {
            if fatigueAdvisory == nil, var plan = trainingPlan {
                plan = SafeBeginnerLayer.applyDeload(to: plan)
                trainingPlan = plan
            }
            fatigueAdvisory = "System suggests recovery emphasis. Volume moderated for safety."
        } else {
            fatigueAdvisory = nil
        }
    }
}

struct DaySummary {
    var workoutTitle: String
    var caloriesRemaining: Int
    var isRestDay: Bool

    static let placeholder = DaySummary(workoutTitle: "Push | Neural Strength", caloriesRemaining: 1280, isRestDay: false)
}

struct WorkoutLog: Identifiable {
    let id = UUID()
    let sessionName: String
    let focus: String
    let completedAt: Date
    let totalExercises: Int
    let totalSets: Int
}

struct DisciplineEntry: Identifiable {
    let id = UUID()
    let date: Date
    let completedTraining: Bool
    let energyLevel: Int
    let sleepQuality: Int
    let stressLevel: Int
}

enum TrainingSplit: String, Identifiable {
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full Body"

    var id: String { rawValue }
}

struct TrainingPlan: Identifiable {
    let id = UUID()
    let week: Int
    let split: TrainingSplit
    let sessions: [WorkoutSession]
    let createdAt: Date
}

struct WorkoutSession: Identifiable {
    let id = UUID()
    let name: String
    let focus: String
    let exercises: [ExercisePrescription]
}

struct ExercisePrescription: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let intent: String
    let restSeconds: Int
}

struct NutritionPlan: Identifiable {
    let id = UUID()
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let meals: [Meal]
}

struct Meal: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct WeeklyAdjustment {
    let weekNumber: Int
    let volumeChangePercent: Int
    let calorieAdjustment: Int
    let notes: String
}

struct RecoveryScore {
    let readiness: Double
    let sleepDebtMinutes: Int
    let subjectiveEnergy: Int
}
