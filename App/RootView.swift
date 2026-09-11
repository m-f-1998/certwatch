import SwiftUI

struct RootView: View {
    @State private var hasCompletedOnboarding = AppSettings.hasCompletedOnboarding

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView {
                    AppSettings.hasCompletedOnboarding = true
                    hasCompletedOnboarding = true
                }
            }
        }
        .background(CertWatchTheme.canvas.ignoresSafeArea())
    }
}
