# ZHYM

ZHYM is a SwiftUI iOS app prototype for adaptive training, nutrition guidance, and discipline tracking. It onboards a user, generates a personalized training + fueling plan from deterministic engines, and then guides daily execution through a tabbed experience (`Today`, `Train`, `Fuel`, `Progress`, `Profile`).

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Abdullah%20Noor-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/abdullah-noor1/)
[![Email](https://img.shields.io/badge/Email-abdullahnoorllc%40gmail.com-EA4335?logo=gmail&logoColor=white)](mailto:abdullahnoorllc@gmail.com)

---

## What this app is about

ZHYM models a coaching-style workflow:

1. **Capture baseline + constraints** (height, weight, experience, objective, sessions/week, equipment, diet, access mode, youth athlete flag).
2. **Generate plans** using local adaptive engines for training split/session templates and nutrition macros/meals.
3. **Guide execution** with session flow, rest timers, exercise cue sheets, and daily discipline check-ins.
4. **Adapt for safety/recovery** by deloading when fatigue patterns appear.
5. **Reflect progress** with session history, set completion, weekly density, and profile/plan summaries.

This repository is currently an on-device prototype (no backend/API integration).

---

## Core features

### 1) Multi-step onboarding
- 3-stage onboarding (`Physical Baseline`, `Training Objective`, `Constraints`).
- Collects key anthropometrics and preference constraints.
- Creates a `ZhymUserProfile` and immediately bootstraps plans.

### 2) Adaptive training plan generation
- Computes split based on sessions/week, experience, and access mode.
- Generates deterministic session templates (full body, upper/lower, push/pull/legs).
- Supports a dedicated **Access Mode** routine (bodyweight/minimal equipment emphasis).
- Applies a **Safe Beginner Layer** to moderate sets, rest, and exercise selection.
- Adds periodic or condition-driven deload behavior.

### 3) Adaptive nutrition planning
- Uses a deterministic BMR + activity factor model.
- Adjusts calories by objective and weekly adjustment signal.
- Enforces floor calories for beginners/youth athletes.
- Computes protein/carbs/fats and returns meal templates by dietary rule (none, vegetarian, halal, custom).

### 4) Daily execution UX
- **Today**: current session snapshot, calories/status, weekly adjustment status, recovery snapshot, discipline score card.
- **Train**: exercise-by-exercise flow with set progression, rest timer, and completion logging.
- **Exercise Guide Sheet**: intent, cues, breathing, and safety notes from a local guide library.
- **Fuel**: macro rings and meal list.
- **Progress**: weekly density chart, set completion card, workout history, adaptation card, and recovery education topics.
- **Profile**: baseline/preferences summary, plan detail, weekly rhythm chart, and profile reset.

### 5) State + persistence
- Central `AppState` (`ObservableObject`) powers all screens.
- Persists profile in `UserDefaults` (`zhym.profile`) and restores on app launch.
- Stores workout logs and discipline entries in-memory during runtime.

---

## Tech stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** iOS (Xcode project)
- **State Management:** `@StateObject`, `@EnvironmentObject`, `@Published`
- **Persistence:** `UserDefaults` (JSON-encoded profile)
- **Architecture style:** lightweight, feature-oriented SwiftUI + local domain engines

No external package dependencies are used in the current codebase.

---

## Project structure

```text
.
├── README.md
└── Zhym/
    ├── Zhym.xcodeproj
    ├── Zhym/
    │   ├── ZhymApp.swift             # app entry
    │   ├── ContentView.swift         # onboarding vs main experience routing
    │   ├── OnboardingView.swift      # profile setup flow
    │   ├── MainExperienceView.swift  # Today/Train/Fuel/Progress/Profile
    │   ├── Models.swift              # domain models + AppState
    │   ├── PlanRepository.swift      # bootstrap/advance plan orchestration
    │   ├── AdaptiveEngines.swift     # training/nutrition/adjustment logic
    │   ├── GuidanceLibrary.swift     # exercise cue library
    │   └── DesignSystem.swift        # palette, typography, card/button style
    ├── ZhymTests/
    └── ZhymUITests/
```

---

## How the app flows (high-level)

1. `ZhymApp` launches `ContentView`.
2. `ContentView` checks `appState.isOnboarded`:
   - false → `OnboardingView`
   - true  → `MainExperienceView`
3. On onboarding completion:
   - build `ZhymUserProfile`
   - call `appState.configureProfile(profile)`
   - `PlanRepository.bootstrapPlans(...)` generates training/nutrition/weekly adjustment.
4. In main tabs:
   - training session completions are logged in `workoutLogs`
   - daily check-ins update `disciplineEntries` and `disciplineScore`
   - fatigue heuristics may apply deload logic and set `fatigueAdvisory`.

---

## Getting started

### Prerequisites
- Xcode 15+
- iOS Simulator (or physical iPhone)

### Run locally
1. Open the project:
   - `Zhym/Zhym.xcodeproj`
2. Select the `Zhym` scheme.
3. Choose an iOS simulator (e.g., iPhone 15/16).
4. Build & Run (`⌘R`).

### Run tests
From Xcode:
- `Product` → `Test` (`⌘U`)

Or from terminal (example):
```bash
xcodebuild test \
  -project Zhym/Zhym.xcodeproj \
  -scheme Zhym \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Current status and limitations

This is a strong prototype foundation, but there are expected gaps:

- Some UI actions are placeholders (e.g., swap suggestion/recovery protocol actions are not fully wired).
- Exercise media previews are placeholder UI in the guide sheet.
- Plan adaptation is heuristic and deterministic (not ML-driven).
- Only profile data is persisted; logs/check-ins are runtime-only.
- Tests are scaffolded and minimal by default.

---

## Suggested next steps

- Add persistent storage for logs/check-ins (Core Data or SQLite).
- Add unit tests for engines (`AdaptiveTrainingEngine`, `NutritionEngine`, `WeeklyAdjustmentEngine`, fatigue scoring).
- Introduce analytics/event instrumentation for onboarding and adherence funnels.
- Wire real media assets for exercise guidance.
- Add export/share for weekly report summaries.
- Optionally add backend sync for multi-device continuity.

---

## License

No license file is currently present in this repository. If you plan to distribute this project, add an explicit license.
