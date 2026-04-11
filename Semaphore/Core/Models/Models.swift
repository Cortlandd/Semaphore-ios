import Foundation

public enum ViewDisplayMode: String, Codable, Equatable, Sendable {
    case loading
    case content
    case empty
    case error
}

public struct Workout: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var createdAt: Int64
    public var name: String
    public var imageLocation: String?
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var position: Int
    public var orderId: Int
    public var completedCount: Int
    public var totalTimeSpentSeconds: Int64
    public var lastPerformedAt: Int64?
    public var currentStreak: Int

    public init(
        id: String,
        createdAt: Int64,
        name: String,
        imageLocation: String?,
        hours: Int,
        minutes: Int,
        seconds: Int,
        position: Int,
        orderId: Int,
        completedCount: Int = 0,
        totalTimeSpentSeconds: Int64 = 0,
        lastPerformedAt: Int64? = nil,
        currentStreak: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.imageLocation = imageLocation
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.position = position
        self.orderId = orderId
        self.completedCount = completedCount
        self.totalTimeSpentSeconds = totalTimeSpentSeconds
        self.lastPerformedAt = lastPerformedAt
        self.currentStreak = currentStreak
    }

    public var durationSeconds: Int {
        (hours * 3_600) + (minutes * 60) + seconds
    }
}

public struct WorkoutLibrarySnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var workouts: [Workout]

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        workouts: [Workout]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.workouts = workouts
    }
}

public struct WorkoutDraft: Equatable, Sendable {
    public var workoutID: String?
    public var name: String
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var currentImageLocation: String?
    public var remoteImageURL: String
    public var selectedMediaData: Data?

    public init(
        workoutID: String?,
        name: String,
        hours: Int,
        minutes: Int,
        seconds: Int,
        currentImageLocation: String?,
        remoteImageURL: String,
        selectedMediaData: Data?
    ) {
        self.workoutID = workoutID
        self.name = name
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.currentImageLocation = currentImageLocation
        self.remoteImageURL = remoteImageURL
        self.selectedMediaData = selectedMediaData
    }
}

public struct AnalyticsSummary: Equatable, Sendable {
    public var totalCompletedWorkouts: Int
    public var totalHours: Double
    public var currentStreak: Int
    public var weeklyProgress: Double

    public init(workouts: [Workout]) {
        self.totalCompletedWorkouts = workouts.reduce(0) { $0 + $1.completedCount }
        self.totalHours = Double(workouts.reduce(Int64(0)) { $0 + $1.totalTimeSpentSeconds }) / 3_600
        self.currentStreak = workouts.map(\.currentStreak).max() ?? 0

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoff = Int64(cutoffDate.timeIntervalSince1970 * 1_000)

        let distinctDays = Set(
            workouts.compactMap { workout -> String? in
                guard let lastPerformedAt = workout.lastPerformedAt, lastPerformedAt >= cutoff else {
                    return nil
                }

                return dayIdentifier(for: lastPerformedAt)
            }
        )

        self.weeklyProgress = min(Double(distinctDays.count) / 5.0, 1.0)
    }
}

public enum MarkdownDocument: String, CaseIterable, Identifiable, Sendable {
    case faq

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .faq:
            return "FAQ"
        }
    }
}

public func formatPlaybackClock(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

public func formatWorkoutDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }

    if minutes > 0 && seconds > 0 {
        return "\(minutes)m \(seconds)s"
    }

    if minutes > 0 {
        return "\(minutes)m"
    }

    return "\(seconds)s"
}

public func formatTrackedDuration(_ totalSeconds: Int64) -> String {
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }

    if minutes > 0 {
        return "\(minutes)m"
    }

    return "\(totalSeconds)s"
}

public func formatLastPerformed(_ timestamp: Int64?) -> String {
    guard let timestamp, timestamp > 0 else {
        return "Never"
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000))
}

public func feedbackMailURL() -> URL {
    URL(
        string: "mailto:cortlandjwalker@gmail.com?subject=Semaphore%20Feedback"
    )!
}

public func dayIdentifier(for timestamp: Int64) -> String {
    let calendar = Calendar.current
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000)
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
}

public func wasPerformedYesterday(_ timestamp: Int64?) -> Bool {
    guard let timestamp else { return false }

    let calendar = Calendar.current
    let lastDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000)
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
        return false
    }

    return calendar.isDate(lastDate, inSameDayAs: yesterday)
}

public func isRemoteURL(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://")
}
