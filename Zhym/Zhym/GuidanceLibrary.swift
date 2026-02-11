import Foundation

struct ExerciseGuide: Identifiable {
    let id = UUID()
    let name: String
    let intent: String
    let cues: [String]
    let breathing: String
    let safety: String
    let mediaAsset: String
}

enum GuidanceLibrary {
    static func guide(for exerciseName: String) -> ExerciseGuide {
        let normalized = exerciseName.lowercased()
        return lookup[normalized] ?? defaultGuide(name: exerciseName)
    }

    private static func defaultGuide(name: String) -> ExerciseGuide {
        ExerciseGuide(
            name: name,
            intent: "Control",
            cues: ["Maintain stacked ribs + pelvis", "Move on a 3-1 tempo"],
            breathing: "Inhale through eccentric, exhale to brace on concentric.",
            safety: "Stop if form breaks or joints pinch.",
            mediaAsset: "placeholder"
        )
    }

    private static let lookup: [String: ExerciseGuide] = {
        var guides: [ExerciseGuide] = [
            ExerciseGuide(
                name: "Tempo Bench Press",
                intent: "Neural strength",
                cues: ["3s lower, 1s pause on chest", "Drive feet through the floor", "Keep eyes fixed on one point"],
                breathing: "Inhale during the lower, hold softly, exhale as you press",
                safety: "Spotter required above 80%. Keep wrists stacked over elbows.",
                mediaAsset: "bench-tempo"
            ),
            ExerciseGuide(
                name: "Ring Rows",
                intent: "Scapular control",
                cues: ["Neutral spine, long from head to heel", "Pull rings to ribs", "Pause for 1s at top"],
                breathing: "Exhale as elbows drive back, inhale during reach",
                safety: "Walk feet forward only as far as you can hold control.",
                mediaAsset: "ring-rows"
            ),
            ExerciseGuide(
                name: "Front Squat",
                intent: "Force production",
                cues: ["Elbows drive forward, chest proud", "Sit between heels", "2s down, sharp drive up"],
                breathing: "Deep breath before descent, brace through concentric",
                safety: "Rack before fatigue compromises posture.",
                mediaAsset: "front-squat"
            ),
            ExerciseGuide(
                name: "Copenhagen Plank",
                intent: "Adductor resilience",
                cues: ["Top leg stays horizontal", "Stack hips and ribs", "Press forearm through floor"],
                breathing: "Smooth inhales through nose, exhale to maintain brace",
                safety: "Lower bottom hip to rest if shaking compromises control.",
                mediaAsset: "copenhagen"
            ),
            ExerciseGuide(
                name: "Power Clean",
                intent: "Speed reserve",
                cues: ["Drive through floor, finish tall", "Bar tracks close", "Meet bar softly in rack"],
                breathing: "Inhale as you settle, hold through pull, exhale once caught",
                safety: "Only load as technique allows — prioritize crisp triples.",
                mediaAsset: "power-clean"
            )
        ]

        var dict: [String: ExerciseGuide] = [:]
        for guide in guides {
            dict[guide.name.lowercased()] = guide
        }
        return dict
    }()
}
