import Foundation

final class PlanRepository {
    private var currentWeek: Int = 1

    func bootstrapPlans(for profile: ZhymUserProfile) -> (TrainingPlan, NutritionPlan, WeeklyAdjustment) {
        let trainingPlan = AdaptiveTrainingEngine.generatePlan(for: profile, weekNumber: currentWeek)
        let adjustment = WeeklyAdjustmentEngine.evaluate(adherence: 0.92, weightTrendDelta: 0, subjectiveEnergy: 7, weekNumber: currentWeek)
        let nutritionPlan = NutritionEngine.generatePlan(for: profile, weekNumber: currentWeek, adjustment: adjustment)
        return (trainingPlan, nutritionPlan, adjustment)
    }

    func advanceWeek(with adherence: Double, weightDelta: Double, energy: Int, profile: ZhymUserProfile) -> (TrainingPlan, NutritionPlan, WeeklyAdjustment) {
        currentWeek += 1
        let adjustment = WeeklyAdjustmentEngine.evaluate(adherence: adherence, weightTrendDelta: weightDelta, subjectiveEnergy: energy, weekNumber: currentWeek)
        let trainingPlan = AdaptiveTrainingEngine.generatePlan(for: profile, weekNumber: currentWeek)
        let nutritionPlan = NutritionEngine.generatePlan(for: profile, weekNumber: currentWeek, adjustment: adjustment)
        return (trainingPlan, nutritionPlan, adjustment)
    }
}
