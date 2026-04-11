import XCTest
@testable import Semaphore

final class WorkoutPlaybackTests: XCTestCase {
    func testResolvePlaybackReturnsCurrentItemAndRemainingTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: "first", name: "First", imageLocation: nil, durationSeconds: 60),
                .init(id: "second", name: "Second", imageLocation: nil, durationSeconds: 45),
            ],
            isPlayingAll: true
        )

        let resolution = resolvePlayback(session: session, now: start.addingTimeInterval(30))

        XCTAssertFalse(resolution.isFinished)
        XCTAssertEqual(resolution.completedCount, 0)
        XCTAssertEqual(resolution.newlyCompleted, [])
        XCTAssertEqual(resolution.presentation?.activeItem.id, "first")
        XCTAssertEqual(resolution.presentation?.remainingSeconds, 30)
        XCTAssertEqual(resolution.remainingQueue, ["second"])
        XCTAssertEqual(resolution.presentation?.isPaused, false)
    }

    func testResolvePlaybackAdvancesToNextItemAndReportsCompletion() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: "first", name: "First", imageLocation: nil, durationSeconds: 60),
                .init(id: "second", name: "Second", imageLocation: nil, durationSeconds: 30),
            ],
            isPlayingAll: true
        )

        let resolution = resolvePlayback(session: session, now: start.addingTimeInterval(61))

        XCTAssertFalse(resolution.isFinished)
        XCTAssertEqual(resolution.completedCount, 1)
        XCTAssertEqual(resolution.newlyCompleted.map(\.item.id), ["first"])
        XCTAssertEqual(resolution.newlyCompleted.first?.completedAt, start.addingTimeInterval(60))
        XCTAssertEqual(resolution.presentation?.activeItem.id, "second")
        XCTAssertEqual(resolution.presentation?.remainingSeconds, 29)
        XCTAssertEqual(resolution.remainingQueue, [])
    }

    func testResolvePlaybackFreezesWhenPaused() {
        let start = Date(timeIntervalSince1970: 1_000)
        let pausedAt = start.addingTimeInterval(80)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: "first", name: "First", imageLocation: nil, durationSeconds: 120),
            ],
            isPlayingAll: false,
            pausedAt: pausedAt,
            accumulatedPauseDuration: 20
        )

        let resolution = resolvePlayback(session: session, now: start.addingTimeInterval(300))

        XCTAssertEqual(resolution.presentation?.activeItem.id, "first")
        XCTAssertEqual(resolution.presentation?.remainingSeconds, 60)
        XCTAssertEqual(resolution.presentation?.isPaused, true)
        XCTAssertFalse(resolution.isFinished)
    }

    func testResolvePlaybackFinishesRoutine() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: "first", name: "First", imageLocation: nil, durationSeconds: 10),
            ],
            isPlayingAll: false
        )

        let resolution = resolvePlayback(session: session, now: start.addingTimeInterval(11))

        XCTAssertTrue(resolution.isFinished)
        XCTAssertNil(resolution.presentation)
        XCTAssertEqual(resolution.completedCount, 1)
        XCTAssertEqual(resolution.newlyCompleted.map(\.item.id), ["first"])
    }
}
