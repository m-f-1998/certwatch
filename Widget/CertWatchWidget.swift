import SwiftUI
import WidgetKit

struct CertWatchSmallWidget: Widget {
    let kind = "CertWatchSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(CertWatchTheme.widgetCanvas, for: .widget)
        }
        .configurationDisplayName("Soonest Certificate")
        .description("Shows the certificate expiring soonest.")
        .supportedFamilies([.systemSmall])
    }
}

struct CertWatchMediumWidget: Widget {
    let kind = "CertWatchMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(CertWatchTheme.widgetCanvas, for: .widget)
        }
        .configurationDisplayName("Certificate Watchlist")
        .description("Shows the top three expiring certificates.")
        .supportedFamilies([.systemMedium])
    }
}
