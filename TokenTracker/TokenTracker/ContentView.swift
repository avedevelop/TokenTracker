import SwiftUI

private let bg = Color(red: 0.09, green: 0.07, blue: 0.14)

struct ContentView: View {
    @EnvironmentObject var orchestrator: AppOrchestrator
    @AppStorage("onboardingComplete") var onboardingComplete = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            if !onboardingComplete {
                OnboardingView(onComplete: { onboardingComplete = true })
            } else if orchestrator.isLoggedIn {
                SettingsView()
            } else {
                LoginView(onLoginSuccess: orchestrator.onLoginSuccess)
            }
        }
        .frame(width: 340)
        .environment(\.colorScheme, .dark)
    }
}
