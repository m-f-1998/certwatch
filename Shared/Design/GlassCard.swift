import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CertWatchTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [CertWatchTheme.cardBorderTop, CertWatchTheme.cardBorderBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            )
    }
}

struct ValidityProgressRail: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: max(4, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Certificate validity progress")
        .accessibilityValue("\(Int(progress * 100)) percent elapsed")
    }
}

struct ExpiryPill: View {
    let text: String
    let status: ExpiryStatus

    var body: some View {
        Text(text)
            .font(CertWatchTheme.monospaced(15, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.14), in: Capsule())
            .accessibilityLabel("\(text) remaining")
    }
}

struct CountdownDial: View {
    let daysRemaining: Int
    let status: ExpiryStatus

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(status.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text(displayDays)
                    .font(CertWatchTheme.monospaced(34, weight: .bold))
                Text("days")
                    .font(.caption)
                    .foregroundStyle(CertWatchTheme.secondaryText)
            }
        }
        .frame(width: 160, height: 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayDays) days remaining")
    }

    private var displayDays: String {
        daysRemaining < 0 ? "EXP" : "\(max(daysRemaining, 0))"
    }

    private var progress: CGFloat {
        guard daysRemaining >= 0 else { return 1 }
        return CGFloat(min(max(Double(daysRemaining) / 90.0, 0.05), 1))
    }
}

struct SecurityBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CertWatchTheme.tertiaryText)
            Text(value)
                .font(CertWatchTheme.monospaced(12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
