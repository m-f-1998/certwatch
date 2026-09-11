import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                onboardingPage(
                    symbol: "shield.lefthalf.filled",
                    title: "Monitor SSL certificates before they expire",
                    subtitle: "Add any hostname and inspect the live TLS chain in seconds."
                )
                .tag(0)

                onboardingPage(
                    symbol: "lock.shield",
                    title: "All data stays on your device",
                    subtitle: "CertWatch only connects to hostnames you enter. No accounts, no tracking, no backend."
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == 1 ? "Get Started" : "Continue") {
                if page == 1 {
                    onFinish()
                } else {
                    page += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CertWatchTheme.healthy)
            .padding(.horizontal)
            .accessibilityLabel(page == 1 ? "Get started" : "Continue onboarding")
        }
        .padding(.vertical, 32)
        .background(CertWatchTheme.canvas)
    }

    private func onboardingPage(symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(CertWatchTheme.healthy)
                .padding(.top, 40)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(CertWatchTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}
