import SwiftUI

private enum OnboardingStage: Int, CaseIterable {
    case baseline
    case objective
    case constraints

    var title: String {
        switch self {
        case .baseline: return "Physical Baseline"
        case .objective: return "Training Objective"
        case .constraints: return "Constraints"
        }
    }

    var subtitle: String {
        switch self {
        case .baseline: return "Precision begins with honest numbers."
        case .objective: return "ZHYM adapts quietly once intent is defined."
        case .constraints: return "Boundaries are inputs, not excuses."
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stage: OnboardingStage = .baseline

    @State private var height: Double = 178
    @State private var weight: Double = 79
    @State private var experience: TrainingExperience = .intermediate
    @State private var objective: TrainingObjective = .strength
    @State private var sessionsPerWeek: Int = 5
    @State private var equipment: TrainingConstraint = .gym
    @State private var dietaryRule: DietaryRule = .none
    @State private var accessMode: AccessMode = .standard
    @State private var isYouthAthlete: Bool = false

    private var canAdvance: Bool { true }

    private var progress: Double {
        Double(stage.rawValue + 1) / Double(OnboardingStage.allCases.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ZHYM")
                        .font(ZhymTypography.display(42))
                        .foregroundStyle(ZhymPalette.platinum)
                    ProgressView(value: progress)
                        .tint(ZhymPalette.platinum)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                    Text("Adaptive strength. Intelligent discipline.")
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(ZhymPalette.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(stage.title.uppercased())
                        .font(ZhymTypography.label(14))
                        .foregroundStyle(ZhymPalette.accent)
                        .tracking(2)
                    Text(stage.subtitle)
                        .font(ZhymTypography.display(28))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stageView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 160)
        }
        .background(ZhymPalette.charcoal.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                if stage != .baseline {
                    Button("Back", action: goBack)
                        .buttonStyle(.secondaryZhym)
                        .transition(.opacity)
                }

                Button(stage == .constraints ? "Enter ZHYM" : "Continue", action: next)
                    .buttonStyle(.primaryZhym)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                LinearGradient(colors: [ZhymPalette.charcoal.opacity(0.95), ZhymPalette.charcoal.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
        .animation(.easeInOut(duration: 0.35), value: stage)
    }

    @ViewBuilder
    private var stageView: some View {
        switch stage {
        case .baseline:
            baselineView
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .objective:
            objectiveView
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .constraints:
            constraintsView
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var baselineView: some View {
        VStack(spacing: 24) {
            sliderCard(title: "Height", value: height, range: 150...210, unit: "cm") { newValue in
                height = newValue
            }
            sliderCard(title: "Weight", value: weight, range: 50...140, unit: "kg") { newValue in
                weight = newValue
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Training experience")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                optionGrid(options: TrainingExperience.allCases, selection: experience) { selected in
                    experience = selected
                }
            }
        }
    }

    private var objectiveView: some View {
        VStack(spacing: 24) {
            Text("Choose the primary adaptation target. ZHYM will adjust everything else quietly.")
                .font(ZhymTypography.label(16))
                .foregroundStyle(ZhymPalette.accent)

            optionGrid(options: TrainingObjective.allCases, selection: objective) { selected in
                objective = selected
            }
        }
    }

    private var constraintsView: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Training days per week")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                Stepper(value: $sessionsPerWeek, in: 3...6) {
                    Text("\(sessionsPerWeek) sessions")
                        .font(ZhymTypography.display(32))
                        .foregroundStyle(.white)
                }
                .zhymCard()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Equipment access")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                optionGrid(options: TrainingConstraint.allCases, selection: equipment) { selected in
                    equipment = selected
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Access mode")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                Picker("Access mode", selection: $accessMode) {
                    ForEach(AccessMode.allCases) { mode in
                        Text(mode.rawValue)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(accessMode.description)
                    .font(ZhymTypography.label(14))
                    .foregroundStyle(ZhymPalette.accent)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Dietary rules")
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                optionGrid(options: DietaryRule.allCases, selection: dietaryRule) { selected in
                    dietaryRule = selected
                }
            }

            Toggle(isOn: $isYouthAthlete) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Youth Athlete (13-18)")
                        .font(ZhymTypography.label(16))
                        .foregroundStyle(.white)
                    Text("Movement quality, recovery education, moderated loading")
                        .font(ZhymTypography.label(13))
                        .foregroundStyle(ZhymPalette.accent)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ZhymPalette.platinum))
        }
    }

    private func sliderCard(title: String, value: Double, range: ClosedRange<Double>, unit: String, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(ZhymTypography.label(16))
                    .foregroundStyle(ZhymPalette.accent)
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(ZhymTypography.numeric(34))
                    .foregroundStyle(.white)
            }
            Slider(value: Binding(get: { value }, set: { onChange($0) }), in: range)
                .tint(ZhymPalette.platinum)
        }
        .zhymCard()
    }

    private func optionGrid<T: Identifiable & RawRepresentable>(options: [T], selection: T, onSelect: @escaping (T) -> Void) -> some View where T.RawValue == String {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(options, id: \.id) { item in
                let isSelected = item.id == selection.id
                Button {
                    onSelect(item)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.rawValue)
                            .font(ZhymTypography.label(17))
                            .foregroundStyle(isSelected ? Color.black : ZhymPalette.platinum)
                        Text(isSelected ? "Selected" : "Tap to choose")
                            .font(ZhymTypography.label(13))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.7) : ZhymPalette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? ZhymPalette.platinum : ZhymPalette.graphite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(ZhymPalette.platinum.opacity(isSelected ? 0.6 : 0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func goBack() {
        guard let previousStage = OnboardingStage(rawValue: stage.rawValue - 1) else { return }
        stage = previousStage
    }

    private func next() {
        if stage == .constraints {
            let metrics = UserMetrics(heightCm: height, weightKg: weight, experience: experience)
            let constraints = ConstraintSummary(sessionsPerWeek: sessionsPerWeek, equipment: equipment, dietaryRule: dietaryRule, accessMode: accessMode)
            let preferences = TrainingPreferences(objective: objective, constraints: constraints, isYouthAthlete: isYouthAthlete)
            let profile = ZhymUserProfile(metrics: metrics, preferences: preferences)
            appState.configureProfile(profile)
            return
        }

        guard let nextStage = OnboardingStage(rawValue: stage.rawValue + 1), canAdvance else { return }
        stage = nextStage
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
