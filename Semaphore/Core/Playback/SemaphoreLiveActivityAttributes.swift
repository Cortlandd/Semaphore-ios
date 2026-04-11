@preconcurrency import ActivityKit
import Foundation

@available(iOS 16.2, *)
public struct SemaphoreLiveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var workoutName: String
        public var startDate: Date
        public var endDate: Date
        public var remainingSeconds: Int
        public var isPlayingAll: Bool
        public var remainingQueueCount: Int
        public var isPaused: Bool
        public var imageData: Data?

        public init(
            workoutName: String,
            startDate: Date,
            endDate: Date,
            remainingSeconds: Int,
            isPlayingAll: Bool,
            remainingQueueCount: Int,
            isPaused: Bool,
            imageData: Data?
        ) {
            self.workoutName = workoutName
            self.startDate = startDate
            self.endDate = endDate
            self.remainingSeconds = remainingSeconds
            self.isPlayingAll = isPlayingAll
            self.remainingQueueCount = remainingQueueCount
            self.isPaused = isPaused
            self.imageData = imageData
        }
    }

    public var routineName: String

    public init(routineName: String) {
        self.routineName = routineName
    }
}
