import Foundation

enum AdaptiveTrainingEngine {
    static func generatePlan(for profile: ZhymUserProfile, weekNumber: Int = 1, previous: TrainingPlan? = nil) -> TrainingPlan {
        let constraints = profile.trainingPreferences.constraints
        let sessions = constraints.sessionsPerWeek
        let split = determineSplit(experience: profile.metrics.experience, sessions: sessions, mode: constraints.accessMode)
        let baseTemplates: [WorkoutSession]
        if constraints.accessMode == .access {
            baseTemplates = AccessWorkoutBuilder.build(sessions: sessions)
        } else {
            baseTemplates = DeterministicWorkoutBuilder.build(split: split, sessions: sessions, objective: profile.trainingPreferences.objective)
        }

        let safeSessions = SafeBeginnerLayer.apply(to: baseTemplates, profile: profile, weekNumber: weekNumber)

        return TrainingPlan(
            week: weekNumber,
            split: split,
            sessions: safeSessions,
            createdAt: .now
        )
    }

    private static func determineSplit(experience: TrainingExperience, sessions: Int, mode: AccessMode) -> TrainingSplit {
        if mode == .access { return .fullBody }
        switch sessions {
        case 3:
            return experience == .advanced ? .pushPullLegs : .fullBody
        case 4:
            return .upperLower
        default:
            return .pushPullLegs
        }
    }
}

enum NutritionEngine {
    static func generatePlan(for profile: ZhymUserProfile, weekNumber: Int = 1, adjustment: WeeklyAdjustment? = nil) -> NutritionPlan {
        let weightKg = profile.metrics.weightKg
        let heightCm = profile.metrics.heightCm
        // Assume age 30, masculine constant +5 for simplicity. Deterministic across users.
        let bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * 30) + 5
        let activityMultiplier = activityFactor(for: profile.trainingPreferences.constraints.sessionsPerWeek)
        var calories = Int((bmr * activityMultiplier).rounded())

        switch profile.trainingPreferences.objective {
        case .muscle:
            calories += 200
        case .fatLoss:
            calories -= profile.trainingPreferences.constraints.accessMode == .access ? 200 : 300
        case .strength:
            calories += 100
        case .balance:
            break
        }

        if let adjustment = adjustment {
            calories += adjustment.calorieAdjustment
        }

        if profile.metrics.experience == .beginner || profile.trainingPreferences.isYouthAthlete {
            let floorCalories = Int((bmr * 1.2).rounded())
            calories = max(calories, floorCalories)
        }

        let protein = Int((weightKg * 2.2).rounded())
        let fats = max(60, Int(Double(calories) * 0.25 / 9))
        let carbsCalories = max(calories - (protein * 4) - (fats * 9), 0)
        let carbs = carbsCalories / 4

        let meals = MealTemplateLibrary.buildMeals(for: profile.trainingPreferences)

        return NutritionPlan(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            meals: meals
        )
    }

    private static func activityFactor(for sessions: Int) -> Double {
        switch sessions {
        case 3: return 1.35
        case 4: return 1.45
        case 5: return 1.5
        default: return 1.6
        }
    }
}

enum WeeklyAdjustmentEngine {
    static func evaluate(adherence: Double, weightTrendDelta: Double, subjectiveEnergy: Int, weekNumber: Int) -> WeeklyAdjustment {
        let volumeChange: Int
        if adherence < 0.8 || subjectiveEnergy < 5 {
            volumeChange = -15
        } else if adherence > 0.95 && subjectiveEnergy > 7 {
            volumeChange = 10
        } else {
            volumeChange = 0
        }

        let calorieAdjustment: Int
        if weightTrendDelta < -0.5 {
            calorieAdjustment = 150
        } else if weightTrendDelta > 0.5 {
            calorieAdjustment = -100
        } else {
            calorieAdjustment = 0
        }

        return WeeklyAdjustment(
            weekNumber: weekNumber,
            volumeChangePercent: volumeChange,
            calorieAdjustment: calorieAdjustment,
            notes: volumeChange < 0 ? "Deload initiated" : "Progressing"
        )
    }
}

private enum DeterministicWorkoutBuilder {
    static func build(split: TrainingSplit, sessions: Int, objective: TrainingObjective) -> [WorkoutSession] {
        switch split {
        case .fullBody:
            return fullBodyTemplate(objective: objective, sessions: sessions)
        case .upperLower:
            return upperLowerTemplate(objective: objective)
        case .pushPullLegs:
            return pushPullLegsTemplate(objective: objective)
        }
    }

    private static func pushPullLegsTemplate(objective: TrainingObjective) -> [WorkoutSession] {
        [
            WorkoutSession(name: "Push", focus: emphasis(for: objective, primary: "Neural strength"), exercises: [
                ExercisePrescription(name: "Tempo Bench Press", sets: 4, reps: "4 @ 75%", intent: "Power", restSeconds: 150),
                ExercisePrescription(name: "Incline Dumbbell Press", sets: 3, reps: "8", intent: "Hypertrophy", restSeconds: 120),
                ExercisePrescription(name: "Ring Push-up", sets: 3, reps: "AMRAP", intent: "Control", restSeconds: 90)
            ]),
            WorkoutSession(name: "Pull", focus: emphasis(for: objective, primary: "Posterior chain"), exercises: [
                ExercisePrescription(name: "Deficit Deadlift", sets: 4, reps: "3 @ 80%", intent: "Strength", restSeconds: 180),
                ExercisePrescription(name: "Chest Supported Row", sets: 4, reps: "10", intent: "Volume", restSeconds: 120),
                ExercisePrescription(name: "Nordic Curl", sets: 3, reps: "6", intent: "Control", restSeconds: 120)
            ]),
            WorkoutSession(name: "Legs", focus: emphasis(for: objective, primary: "Power + Stability"), exercises: [
                ExercisePrescription(name: "Front Squat", sets: 4, reps: "5", intent: "Power", restSeconds: 150),
                ExercisePrescription(name: "Split Squat", sets: 3, reps: "8", intent: "Volume", restSeconds: 120),
                ExercisePrescription(name: "Copenhagen Plank", sets: 3, reps: "30s", intent: "Stability", restSeconds: 60)
            ])
        ]
    }

    private static func upperLowerTemplate(objective: TrainingObjective) -> [WorkoutSession] {
        [
            WorkoutSession(name: "Upper Neural", focus: emphasis(for: objective, primary: "Strength density"), exercises: [
                ExercisePrescription(name: "Bench Press", sets: 5, reps: "3", intent: "Neural", restSeconds: 180),
                ExercisePrescription(name: "Weighted Pull-up", sets: 4, reps: "5", intent: "Strength", restSeconds: 150),
                ExercisePrescription(name: "Seated Row", sets: 3, reps: "10", intent: "Volume", restSeconds: 90)
            ]),
            WorkoutSession(name: "Lower Power", focus: emphasis(for: objective, primary: "Force production"), exercises: [
                ExercisePrescription(name: "Back Squat", sets: 5, reps: "5", intent: "Neural", restSeconds: 180),
                ExercisePrescription(name: "Romanian Deadlift", sets: 3, reps: "8", intent: "Hypertrophy", restSeconds: 120),
                ExercisePrescription(name: "Anti-rotation Hold", sets: 3, reps: "40s", intent: "Core", restSeconds: 60)
            ])
        ]
    }

    private static func fullBodyTemplate(objective: TrainingObjective, sessions: Int) -> [WorkoutSession] {
        let base = [
            WorkoutSession(name: "Full Body A", focus: emphasis(for: objective, primary: "Compound balance"), exercises: [
                ExercisePrescription(name: "Trap-bar Deadlift", sets: 4, reps: "5", intent: "Power", restSeconds: 150),
                ExercisePrescription(name: "Floor Press", sets: 4, reps: "6", intent: "Strength", restSeconds: 120),
                ExercisePrescription(name: "Single-leg RDL", sets: 3, reps: "8/side", intent: "Control", restSeconds: 90)
            ]),
            WorkoutSession(name: "Full Body B", focus: emphasis(for: objective, primary: "Athletic volume"), exercises: [
                ExercisePrescription(name: "Front Squat", sets: 4, reps: "5", intent: "Strength", restSeconds: 150),
                ExercisePrescription(name: "Chin-up", sets: 4, reps: "8", intent: "Volume", restSeconds: 90),
                ExercisePrescription(name: "Farmer Carry", sets: 3, reps: "40m", intent: "Capacity", restSeconds: 120)
            ])
        ]

        if sessions == 3 {
            return base + [
                WorkoutSession(name: "Full Body C", focus: emphasis(for: objective, primary: "Speed reserve"), exercises: [
                    ExercisePrescription(name: "Power Clean", sets: 5, reps: "3", intent: "Power", restSeconds: 150),
                    ExercisePrescription(name: "Push Press", sets: 4, reps: "6", intent: "Strength", restSeconds: 120),
                    ExercisePrescription(name: "Hollow Body Hold", sets: 3, reps: "45s", intent: "Core", restSeconds: 60)
                ])
            ]
        }

        return base
    }

    private static func emphasis(for objective: TrainingObjective, primary: String) -> String {
        switch objective {
        case .muscle:
            return "Hypertrophy emphasis — " + primary
        case .fatLoss:
            return "Output & density — " + primary
        case .strength:
            return "Force priority — " + primary
        case .balance:
            return "Balanced — " + primary
        }
    }
}

private enum AccessWorkoutBuilder {
    static func build(sessions: Int) -> [WorkoutSession] {
        let routine = [
            WorkoutSession(name: "Access Flow A", focus: "Space-efficient strength", exercises: [
                ExercisePrescription(name: "Tempo Push-up", sets: 3, reps: "10", intent: "Control", restSeconds: 60),
                ExercisePrescription(name: "Backpack Row", sets: 3, reps: "12", intent: "Stability", restSeconds: 75),
                ExercisePrescription(name: "Split Squat (Bodyweight)", sets: 3, reps: "10/side", intent: "Balance", restSeconds: 60)
            ]),
            WorkoutSession(name: "Access Flow B", focus: "Mobility + Core", exercises: [
                ExercisePrescription(name: "Glute Bridge", sets: 3, reps: "12", intent: "Activation", restSeconds: 60),
                ExercisePrescription(name: "Plank Reach", sets: 3, reps: "30s", intent: "Core", restSeconds: 45),
                ExercisePrescription(name: "Lateral Lunge", sets: 3, reps: "8/side", intent: "Control", restSeconds: 60)
            ]),
            WorkoutSession(name: "Access Flow C", focus: "Aerobic discipline", exercises: [
                ExercisePrescription(name: "March + Knee Drive", sets: 3, reps: "45s", intent: "Capacity", restSeconds: 30),
                ExercisePrescription(name: "Backpack Overhead Press", sets: 3, reps: "10", intent: "Strength", restSeconds: 75),
                ExercisePrescription(name: "Quadruped Hold", sets: 3, reps: "40s", intent: "Stability", restSeconds: 45)
            ])
        ]

        if sessions <= 3 { return Array(routine.prefix(sessions)) }
        return routine + routine.prefix(max(0, sessions - routine.count))
    }
}

enum SafeBeginnerLayer {
    static func apply(to sessions: [WorkoutSession], profile: ZhymUserProfile, weekNumber: Int) -> [WorkoutSession] {
        var adjusted = sessions.map { session -> WorkoutSession in
            let safeExercises = session.exercises.map { exercise -> ExercisePrescription in
                var sets = exercise.sets
                if profile.metrics.experience == .beginner || profile.trainingPreferences.isYouthAthlete {
                    sets = max(2, exercise.sets - 1)
                }
                return ExercisePrescription(name: exercise.name, sets: sets, reps: exercise.reps, intent: exercise.intent, restSeconds: min(120, exercise.restSeconds))
            }
            return WorkoutSession(name: session.name, focus: safetyFocus(for: session.focus, profile: profile), exercises: safeExercises)
        }

        if shouldInsertDeload(weekNumber: weekNumber, profile: profile) {
            adjusted = applyDeloadSessions(adjusted)
        }

        if profile.trainingPreferences.isYouthAthlete {
            adjusted = adjusted.map { session in
                let filtered = session.exercises.filter { !$0.name.lowercased().contains("deadlift") && !$0.name.lowercased().contains("clean") }
                return WorkoutSession(name: session.name + " • Youth", focus: session.focus + " — movement quality", exercises: filtered.isEmpty ? session.exercises : filtered)
            }
        }

        return adjusted
    }

    static func applyDeload(to plan: TrainingPlan) -> TrainingPlan {
        let reduced = plan.sessions.map { session in
            WorkoutSession(name: session.name + " (Deload)", focus: session.focus, exercises: session.exercises.map { exercise in
                ExercisePrescription(name: exercise.name, sets: max(1, exercise.sets - 1), reps: exercise.reps, intent: exercise.intent, restSeconds: exercise.restSeconds)
            })
        }
        return TrainingPlan(week: plan.week, split: plan.split, sessions: reduced, createdAt: plan.createdAt)
    }

    private static func shouldInsertDeload(weekNumber: Int, profile: ZhymUserProfile) -> Bool {
        profile.metrics.experience == .beginner || profile.trainingPreferences.isYouthAthlete || weekNumber % 4 == 0
    }

    private static func applyDeloadSessions(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.map { session in
            WorkoutSession(name: session.name + " • Recovery", focus: session.focus + " — reduced load", exercises: session.exercises.map { exercise in
                ExercisePrescription(name: exercise.name, sets: max(1, exercise.sets - 1), reps: exercise.reps, intent: exercise.intent, restSeconds: exercise.restSeconds)
            })
        }
    }

    private static func safetyFocus(for focus: String, profile: ZhymUserProfile) -> String {
        if profile.trainingPreferences.constraints.accessMode == .access {
            return "Safe space training — " + focus
        }
        if profile.trainingPreferences.isYouthAthlete {
            return "Youth-safe — " + focus
        }
        if profile.metrics.experience == .beginner {
            return "Technique-first — " + focus
        }
        return focus
    }
}

private enum MealTemplateLibrary {
    static func buildMeals(for preferences: TrainingPreferences) -> [Meal] {
        let base = [
            Meal(title: "Breakfast", description: "Steel cut oats, omega eggs, berries"),
            Meal(title: "Lunch", description: "Charred salmon, citrus quinoa, greens"),
            Meal(title: "Dinner", description: "Flat iron steak, roasted parsnip, fennel"),
            Meal(title: "Optional", description: "Cold brew isolate, almonds")
        ]

        switch preferences.constraints.dietaryRule {
        case .none:
            return base
        case .vegetarian:
            return [
                Meal(title: "Breakfast", description: "Greek yogurt, chia, fig"),
                Meal(title: "Lunch", description: "Smoked tofu, black rice, greens"),
                Meal(title: "Dinner", description: "Paneer tikka, roasted roots"),
                Meal(title: "Optional", description: "Matcha protein, walnuts")
            ]
        case .halal:
            return [
                Meal(title: "Breakfast", description: "Labneh, seeded flatbread, honey"),
                Meal(title: "Lunch", description: "Grilled chicken, saffron rice, cucumber"),
                Meal(title: "Dinner", description: "Braised lamb, charred vegetables"),
                Meal(title: "Optional", description: "Date shake, pistachios")
            ]
        case .custom:
            return base
        }
    }
}
