import SwiftUI

enum ExpiryStatus: Equatable, Sendable {
    case healthy
    case warning
    case critical
    case expired
    case unreachable

    var color: Color {
        switch self {
        case .healthy: return CertWatchTheme.healthy
        case .warning: return CertWatchTheme.warning
        case .critical, .expired: return CertWatchTheme.critical
        case .unreachable: return CertWatchTheme.muted
        }
    }

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .expired: return "Expired"
        case .unreachable: return "Unreachable"
        }
    }
}

enum ExpiryBadgeStyle {
    static func status(for endpoint: MonitoredEndpoint, now: Date = .now) -> ExpiryStatus {
        guard endpoint.isReachable, let validUntil = endpoint.validUntil else {
            return .unreachable
        }

        let days = daysRemaining(until: validUntil, from: now)
        if days < 0 { return .expired }
        if days <= 7 { return .critical }
        if days <= 30 { return .warning }
        return .healthy
    }

    static func daysRemaining(until date: Date, from now: Date = .now) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func validityProgress(validFrom: Date?, validUntil: Date?, now: Date = .now) -> Double {
        guard let validFrom, let validUntil, validUntil > validFrom else { return 0 }
        let total = validUntil.timeIntervalSince(validFrom)
        let elapsed = now.timeIntervalSince(validFrom)
        return min(max(elapsed / total, 0), 1)
    }

    static func pillText(for endpoint: MonitoredEndpoint, now: Date = .now) -> String {
        guard endpoint.isReachable, let validUntil = endpoint.validUntil else {
            return "—"
        }
        let days = daysRemaining(until: validUntil, from: now)
        if days < 0 { return "EXP" }
        return "\(days)d"
    }
}
