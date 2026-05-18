import SwiftUI

struct ContentView: View {
    @EnvironmentObject var orchestrator: AppOrchestrator
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @AppStorage("appColorScheme") var appColorScheme: String = "dark"
    @Environment(\.colorScheme) var systemColorScheme

    private var resolvedScheme: ColorScheme {
        switch appColorScheme {
        case "light": return .light
        case "system": return systemColorScheme
        default: return .dark
        }
    }

    private var bg: Color {
        resolvedScheme == .dark
            ? Color(red: 0.09, green: 0.07, blue: 0.14)
            : Color(.windowBackgroundColor)
    }

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
        .environment(\.colorScheme, resolvedScheme)
    }
}
