import Foundation

enum DateFormatting {
    private static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let weekdayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM yyyy"
        return formatter
    }()

    static func mediumDateTime(_ date: Date) -> String {
        mediumDateTime.string(from: date)
    }

    static func mediumDate(_ date: Date) -> String {
        mediumDate.string(from: date)
    }

    static func weekdayDate(_ date: Date) -> String {
        weekdayDate.string(from: date)
    }

    static func relativeDaysAndHours(until date: Date, from now: Date = .now) -> String {
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "Expired" }

        let days = Int(interval / 86_400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86_400)) / 3_600)

        if days > 0 {
            return hours > 0 ? "\(days) days, \(hours) hours" : "\(days) days"
        }
        return "\(max(hours, 1)) hours"
    }
}
