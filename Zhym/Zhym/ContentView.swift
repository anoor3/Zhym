import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isOnboarded {
                MainExperienceView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
