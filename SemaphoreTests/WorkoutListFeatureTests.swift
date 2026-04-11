import ComposableArchitecture
import XCTest
@testable import Semaphore

@MainActor
final class WorkoutListFeatureTests: XCTestCase {
    func testPlaybackRestoredPausedSessionReconcilesState() async {
        let workout = makeWorkout(id: "first", seconds: 60)
        let start = Date(timeIntervalSince1970: 1_000)
        let pausedAt = start.addingTimeInterval(15)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: workout.id, name: workout.name, imageLocation: nil, durationSeconds: 60),
            ],
            isPlayingAll: false,
            pausedAt: pausedAt
        )

        var initialState = WorkoutListFeature.State()
        initialState.workouts = [workout]

        let store = TestStore(initialState: initialState) {
            WorkoutListFeature()
        }
        store.dependencies.workoutPlayback.update = { _, _ in }

        await store.send(.playbackRestored(session)) {
            $0.playbackSession = session
            $0.isPlayingAll = false
            $0.isPlaybackPaused = true
            $0.playbackQueue = []
            $0.activeWorkoutId = workout.id
            $0.activeWorkoutRemainingSeconds = 45
        }

        await store.skipInFlightEffects()
    }

    func testTimerTickCompletesWorkoutAndClearsPlayback() async {
        let start = Date().addingTimeInterval(-5)
        let workout = makeWorkout(id: "first", seconds: 3)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: workout.id, name: workout.name, imageLocation: nil, durationSeconds: 3),
            ],
            isPlayingAll: false
        )

        var initialState = WorkoutListFeature.State()
        initialState.workouts = [workout]
        initialState.displayMode = .content
        initialState.playbackSession = session

        let store = TestStore(initialState: initialState) {
            WorkoutListFeature()
        }
        store.dependencies.workoutPlayback.stop = {}

        await store.send(.timerTick) {
            $0.workouts[0].completedCount = 1
            $0.workouts[0].totalTimeSpentSeconds = 3
            $0.workouts[0].lastPerformedAt = millisecondsSince1970(start.addingTimeInterval(3))
            $0.workouts[0].currentStreak = 1
            $0.playbackSession = nil
            $0.isPlayingAll = false
            $0.isPlaybackPaused = false
            $0.playbackQueue = []
            $0.activeWorkoutId = nil
            $0.activeWorkoutRemainingSeconds = nil
        }

        await store.receive(.delegate(.workoutsChanged))
        await store.skipInFlightEffects()
    }

    func testPauseTappedMarksSessionPaused() async {
        let workout = makeWorkout(id: "first", seconds: 60)
        let start = Date()
        let pausedAt = start.addingTimeInterval(8)
        let session = WorkoutPlaybackSession(
            startedAt: start,
            items: [
                .init(id: workout.id, name: workout.name, imageLocation: nil, durationSeconds: 60),
            ],
            isPlayingAll: false
        )

        var initialState = WorkoutListFeature.State()
        initialState.workouts = [workout]
        initialState.playbackSession = session

        let store = TestStore(initialState: initialState) {
            WorkoutListFeature()
        }
        store.dependencies.workoutPlayback.pause = {
            WorkoutPlaybackSession(
                startedAt: start,
                items: session.items,
                isPlayingAll: false,
                appliedCompletionCount: 0,
                pausedAt: pausedAt,
                accumulatedPauseDuration: 0
            )
        }
        store.dependencies.workoutPlayback.update = { _, _ in }

        await store.send(.pauseTapped) {
            $0.playbackSession?.pausedAt = pausedAt
            $0.isPlayingAll = false
            $0.isPlaybackPaused = true
            $0.playbackQueue = []
            $0.activeWorkoutId = workout.id
            $0.activeWorkoutRemainingSeconds = 60
        }

        await store.skipInFlightEffects()
    }

    func testDeleteTappedStopsPlaybackWhenDeletingActiveWorkout() async {
        let workout = makeWorkout(id: "first", seconds: 45)
        let session = WorkoutPlaybackSession(
            startedAt: Date(),
            items: [
                .init(id: workout.id, name: workout.name, imageLocation: nil, durationSeconds: 45),
            ],
            isPlayingAll: false
        )

        var initialState = WorkoutListFeature.State()
        initialState.workouts = [workout]
        initialState.displayMode = .content
        initialState.playbackSession = session
        initialState.activeWorkoutId = workout.id
        initialState.activeWorkoutRemainingSeconds = 45

        let store = TestStore(initialState: initialState) {
            WorkoutListFeature()
        }
        store.dependencies.workoutPlayback.stop = {}

        await store.send(.deleteTapped(workout.id)) {
            $0.workouts = []
            $0.displayMode = .empty
            $0.playbackSession = nil
            $0.isPlayingAll = false
            $0.isPlaybackPaused = false
            $0.playbackQueue = []
            $0.activeWorkoutId = nil
            $0.activeWorkoutRemainingSeconds = nil
        }

        await store.receive(.delegate(.workoutsChanged))
        await store.skipInFlightEffects()
    }
}
