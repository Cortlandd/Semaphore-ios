import XCTest
@testable import Semaphore

final class ModelLogicTests: XCTestCase {
    func testAnalyticsSummaryAggregatesWorkouts() {
        let calendar = Calendar.current
        let now = Date()
        let today = millisecondsSince1970(now)
        let yesterday = millisecondsSince1970(
            calendar.date(byAdding: .day, value: -1, to: now)!
        )
        let older = millisecondsSince1970(
            calendar.date(byAdding: .day, value: -10, to: now)!
        )

        let workouts = [
            makeWorkout(
                id: "a",
                completedCount: 2,
                totalTimeSpentSeconds: 3_600,
                lastPerformedAt: today,
                currentStreak: 3
            ),
            makeWorkout(
                id: "b",
                completedCount: 1,
                totalTimeSpentSeconds: 1_800,
                lastPerformedAt: yesterday,
                currentStreak: 1
            ),
            makeWorkout(
                id: "c",
                completedCount: 4,
                totalTimeSpentSeconds: 900,
                lastPerformedAt: older,
                currentStreak: 2
            ),
        ]

        let summary = AnalyticsSummary(workouts: workouts)

        XCTAssertEqual(summary.totalCompletedWorkouts, 7)
        XCTAssertEqual(summary.totalHours, 1.75, accuracy: 0.0001)
        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.weeklyProgress, 0.4, accuracy: 0.0001)
    }

    func testFormattingHelpers() {
        XCTAssertEqual(formatPlaybackClock(59), "00:59")
        XCTAssertEqual(formatPlaybackClock(3_661), "01:01:01")
        XCTAssertEqual(formatWorkoutDuration(125), "2m 5s")
        XCTAssertEqual(formatWorkoutDuration(3_720), "1h 2m")
        XCTAssertEqual(formatTrackedDuration(90), "1m")
        XCTAssertEqual(formatTrackedDuration(3_660), "1h 1m")
    }

    func testRemoteURLAndYesterdayHelpers() {
        XCTAssertTrue(isRemoteURL(" https://example.com/gif "))
        XCTAssertTrue(isRemoteURL("http://example.com/gif"))
        XCTAssertFalse(isRemoteURL("file:///tmp/example.gif"))

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(wasPerformedYesterday(millisecondsSince1970(yesterday)))
        XCTAssertFalse(wasPerformedYesterday(nil))
    }
}
