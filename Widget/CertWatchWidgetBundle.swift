import SwiftUI
import WidgetKit

@main
struct CertWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        CertWatchSmallWidget()
        CertWatchMediumWidget()
    }
}
