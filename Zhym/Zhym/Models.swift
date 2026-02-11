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

struct UserMetrics: Codable {
    var heightCm: Double
    var weightKg: Double
    var experience: TrainingExperience
}

struct TrainingPreferences: Codable {
    var objective: TrainingObjective
    var constraints: ConstraintSummary
}

struct ConstraintSummary: Codable {
    var sessionsPerWeek: Int
    var equipment: TrainingConstraint
    var dietaryRule: DietaryRule
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
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func recordWorkout(session: WorkoutSession) {
        let totalSets = session.exercises.map { $0.sets }.reduce(0, +)
        let log = WorkoutLog(sessionName: session.name, focus: session.focus, completedAt: Date(), totalExercises: session.exercises.count, totalSets: totalSets)
        workoutLogs.insert(log, at: 0)
        if workoutLogs.count > 20 {
            workoutLogs.removeLast()
        }
    }

    private func applyProfile(_ profile: ZhymUserProfile) {
        let payload = planRepository.bootstrapPlans(for: profile)
        activeProfile = profile
        trainingPlan = payload.0
        nutritionPlan = payload.1
        weeklyAdjustment = payload.2
        activeSessionIndex = 0
        currentDaySummary = DaySummary(
            workoutTitle: payload.0.sessions.first?.name ?? "Rest",
            caloriesRemaining: payload.1.calories,
            isRestDay: payload.0.sessions.isEmpty
        )
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
