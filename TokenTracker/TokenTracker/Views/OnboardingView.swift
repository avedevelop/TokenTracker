import SwiftUI

private let bg = Color(red: 0.09, green: 0.07, blue: 0.14)

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Group {
                        switch currentPage {
                        case 0: welcomePage
                        case 1: featuresPage
                        default: setupPage
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    .id(currentPage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? .white : .white.opacity(0.2))
                                .frame(width: i == currentPage ? 7 : 5, height: i == currentPage ? 7 : 5)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }

                    if currentPage < pageCount - 1 {
                        Button { withAnimation { currentPage += 1 } } label: {
                            HStack(spacing: 6) {
                                Text(L10n.onboardingNext).font(.system(size: 14, weight: .semibold))
                                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    } else {
                        Button { onComplete() } label: {
                            Text(L10n.onboardingStart)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)
                .padding(.top, 12)
            }
        }
        .frame(width: 340, height: 520)
        .environment(\.colorScheme, .dark)
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.06)).frame(width: 90, height: 90)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            VStack(spacing: 8) {
                Text("TokenTracker")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(L10n.onboardingSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var featuresPage: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.onboardingFeaturesTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)
                featureRow(icon: "chart.bar.fill", title: L10n.feat1Title, description: L10n.feat1Body)
                featureRow(icon: "bell.fill",      title: L10n.feat2Title, description: L10n.feat2Body)
                featureRow(icon: "clock.fill",     title: L10n.feat3Title, description: L10n.feat3Body)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.75))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                Text(description).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var setupPage: some View {
        let detected = LimitsPoller().readClaudeCodeOAuthToken() != nil
        return VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.06)).frame(width: 72, height: 72)
                    Image(systemName: detected ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(detected ? Color.green.opacity(0.85) : .white.opacity(0.6))
                }
                Text(L10n.onboardingSetupTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: detected ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(detected ? Color.green.opacity(0.85) : .white.opacity(0.5))
                        .font(.system(size: 16))
                    Text(detected ? L10n.onboardingClaudeDetected : L10n.onboardingNoCredentials)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(detected ? Color.green.opacity(0.2) : .white.opacity(0.08), lineWidth: 0.5))
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .frame(width: 340, height: 520)
}
