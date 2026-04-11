import Foundation
@testable import Semaphore

func makeWorkout(
    id: String = UUID().uuidString,
    createdAt: Int64 = 1_000,
    name: String = "Workout",
    imageLocation: String? = nil,
    hours: Int = 0,
    minutes: Int = 0,
    seconds: Int = 30,
    position: Int = 0,
    orderId: Int = 0,
    completedCount: Int = 0,
    totalTimeSpentSeconds: Int64 = 0,
    lastPerformedAt: Int64? = nil,
    currentStreak: Int = 0
) -> Workout {
    Workout(
        id: id,
        createdAt: createdAt,
        name: name,
        imageLocation: imageLocation,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        position: position,
        orderId: orderId,
        completedCount: completedCount,
        totalTimeSpentSeconds: totalTimeSpentSeconds,
        lastPerformedAt: lastPerformedAt,
        currentStreak: currentStreak
    )
}

func millisecondsSince1970(_ date: Date) -> Int64 {
    Int64(date.timeIntervalSince1970 * 1_000)
}

func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

actor SaveRecorder {
    private var snapshots: [[Workout]] = []

    func record(_ workouts: [Workout]) {
        snapshots.append(workouts)
    }

    func lastSnapshot() -> [Workout]? {
        snapshots.last
    }
}
