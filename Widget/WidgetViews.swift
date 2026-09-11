import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: EndpointSnapshot

    var body: some View {
        if let endpoint = entry.endpoints.first {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(endpoint.status.color).frame(width: 8, height: 8)
                    Text(endpoint.title)
                        .font(.headline)
                        .foregroundStyle(CertWatchTheme.widgetPrimaryText)
                        .lineLimit(1)
                }
                Text("\(max(endpoint.daysRemaining, 0))d")
                    .font(CertWatchTheme.monospaced(28, weight: .bold))
                    .foregroundStyle(endpoint.status.color)
                Text("Expires soonest")
                    .font(.caption)
                    .foregroundStyle(CertWatchTheme.widgetSecondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if AppSettings.isProUnlocked {
            Text("No endpoints yet")
                .font(.caption)
                .foregroundStyle(CertWatchTheme.widgetSecondaryText)
        } else {
            Text("Unlock Pro for widgets")
                .font(.caption)
                .foregroundStyle(CertWatchTheme.widgetSecondaryText)
        }
    }
}

struct MediumWidgetView: View {
    let entry: EndpointSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CertWatch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CertWatchTheme.widgetSecondaryText)

            if entry.endpoints.isEmpty {
                Text(AppSettings.isProUnlocked ? "Add domains in the app" : "Pro unlock required")
                    .font(.caption)
                    .foregroundStyle(CertWatchTheme.widgetSecondaryText)
            } else {
                ForEach(entry.endpoints) { endpoint in
                    HStack {
                        Circle().fill(endpoint.status.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(endpoint.hostPortLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CertWatchTheme.widgetPrimaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(max(endpoint.daysRemaining, 0))d")
                            .font(CertWatchTheme.monospaced(14, weight: .bold))
                            .foregroundStyle(endpoint.status.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
