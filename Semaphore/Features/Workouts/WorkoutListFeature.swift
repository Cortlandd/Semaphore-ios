import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

@Reducer
public struct WorkoutListFeature {
    @ObservableState
    public struct State: Equatable {
        public var workouts: [Workout] = []
        public var displayMode: ViewDisplayMode = .loading
        public var error: String?
        public var playbackSession: WorkoutPlaybackSession?
        public var isPlayingAll = false
        public var isPlaybackPaused = false
        public var playbackQueue: [String] = []
        public var activeWorkoutId: String?
        public var activeWorkoutRemainingSeconds: Int?

        public init() {}

        public var activeWorkoutTimer: String? {
            guard let activeWorkoutRemainingSeconds else { return nil }
            return formatPlaybackClock(activeWorkoutRemainingSeconds)
        }
    }

    public enum Action: Equatable {
        case refreshPlayback
        case playbackRestored(WorkoutPlaybackSession?)
        case addTapped
        case settingsTapped
        case workoutTapped(String)
        case deleteTapped(String)
        case moveWorkout(from: Int, to: Int)
        case playAllTapped
        case singlePlayTapped(String)
        case pauseTapped
        case resumeTapped
        case stopTapped
        case timerTick
        case delegate(Delegate)
    }

    public enum Delegate: Equatable {
        case addWorkoutRequested
        case editWorkoutRequested(String)
        case settingsRequested
        case workoutsChanged
    }

    private enum CancelID {
        case timer
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.workoutPlayback) var workoutPlayback

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshPlayback:
                let workoutPlayback = self.workoutPlayback
                return .run { send in
                    await send(.playbackRestored(await workoutPlayback.restore()))
                }

            case .playbackRestored(let restoredSession):
                state.playbackSession = restoredSession
                let reconcileEffect = reconcilePlayback(state: &state)

                guard let restoredSession, !restoredSession.isPaused else {
                    return .merge(
                        .cancel(id: CancelID.timer),
                        reconcileEffect
                    )
                }

                return .merge(
                    timerEffect(),
                    reconcileEffect
                )

            case .addTapped:
                return .send(.delegate(.addWorkoutRequested))

            case .settingsTapped:
                return .send(.delegate(.settingsRequested))

            case .workoutTapped(let workoutID):
                return .send(.delegate(.editWorkoutRequested(workoutID)))

            case .deleteTapped(let workoutID):
                state.workouts.removeAll { $0.id == workoutID }
                reindexWorkouts(&state.workouts)
                state.displayMode = state.workouts.isEmpty ? .empty : .content

                if state.playbackSession?.items.contains(where: { $0.id == workoutID }) == true {
                    clearPlayback(&state)
                    return .merge(
                        .cancel(id: CancelID.timer),
                        stopPlaybackEffect(),
                        .send(.delegate(.workoutsChanged))
                    )
                }

                return .send(.delegate(.workoutsChanged))

            case let .moveWorkout(from, to):
                guard from != to, state.workouts.indices.contains(from) else {
                    return .none
                }

                let destination = max(0, min(to, state.workouts.count - 1))
                let workout = state.workouts.remove(at: from)
                state.workouts.insert(workout, at: destination)
                reindexWorkouts(&state.workouts)
                return .send(.delegate(.workoutsChanged))

            case .playAllTapped:
                guard !state.workouts.isEmpty, state.playbackSession == nil else { return .none }

                let session = WorkoutPlaybackSession(
                    startedAt: Date(),
                    items: state.workouts.map {
                        WorkoutPlaybackSession.Item(
                            id: $0.id,
                            name: $0.name,
                            imageLocation: $0.imageLocation,
                            durationSeconds: max($0.durationSeconds, 1)
                        )
                    },
                    isPlayingAll: true
                )
                state.playbackSession = session

                let startEffect = startPlaybackEffect(
                    session: session,
                    presentation: resolvePlayback(session: session).presentation
                )

                return .merge(
                    startEffect,
                    timerEffect(),
                    reconcilePlayback(state: &state)
                )

            case .singlePlayTapped(let workoutID):
                if state.activeWorkoutId == workoutID {
                    if state.isPlaybackPaused {
                        guard let session = resumedSession(from: state.playbackSession) else {
                            return .none
                        }
                        state.playbackSession = session
                        return .merge(
                            resumePlaybackEffect(),
                            timerEffect(),
                            reconcilePlayback(state: &state)
                        )
                    } else {
                        guard let session = pausedSession(from: state.playbackSession) else {
                            return .none
                        }
                        state.playbackSession = session
                        return .merge(
                            .cancel(id: CancelID.timer),
                            pausePlaybackEffect(),
                            reconcilePlayback(state: &state)
                        )
                    }
                }

                guard let workout = state.workouts.first(where: { $0.id == workoutID }) else {
                    return .none
                }

                let session = WorkoutPlaybackSession(
                    startedAt: Date(),
                    items: [
                        WorkoutPlaybackSession.Item(
                            id: workout.id,
                            name: workout.name,
                            imageLocation: workout.imageLocation,
                            durationSeconds: max(workout.durationSeconds, 1)
                        )
                    ],
                    isPlayingAll: false
                )
                state.playbackSession = session

                let startEffect = startPlaybackEffect(
                    session: session,
                    presentation: resolvePlayback(session: session).presentation
                )

                return .merge(
                    startEffect,
                    timerEffect(),
                    reconcilePlayback(state: &state)
                )

            case .pauseTapped:
                guard let session = pausedSession(from: state.playbackSession) else {
                    return .none
                }
                state.playbackSession = session
                return .merge(
                    .cancel(id: CancelID.timer),
                    pausePlaybackEffect(),
                    reconcilePlayback(state: &state)
                )

            case .resumeTapped:
                guard let session = resumedSession(from: state.playbackSession) else {
                    return .none
                }
                state.playbackSession = session
                return .merge(
                    resumePlaybackEffect(),
                    timerEffect(),
                    reconcilePlayback(state: &state)
                )

            case .stopTapped:
                clearPlayback(&state)
                return .merge(
                    .cancel(id: CancelID.timer),
                    stopPlaybackEffect()
                )

            case .timerTick:
                return reconcilePlayback(state: &state)

            case .delegate:
                return .none
            }
        }
    }

    private func timerEffect() -> Effect<Action> {
        let clock = self.clock
        return .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.timerTick)
            }
        }
        .cancellable(id: CancelID.timer, cancelInFlight: true)
    }

    private func clearPlayback(_ state: inout State) {
        state.playbackSession = nil
        state.isPlayingAll = false
        state.isPlaybackPaused = false
        state.playbackQueue = []
        state.activeWorkoutId = nil
        state.activeWorkoutRemainingSeconds = nil
    }

    private func reindexWorkouts(_ workouts: inout [Workout]) {
        for index in workouts.indices {
            workouts[index].position = index
        }
    }

    private func reconcilePlayback(state: inout State) -> Effect<Action> {
        guard let session = state.playbackSession else {
            clearPlayback(&state)
            return .none
        }

        let previousActiveWorkoutID = state.activeWorkoutId
        let resolution = resolvePlayback(session: session)
        var updatedSession = session
        updatedSession.appliedCompletionCount = resolution.completedCount

        applyCompletions(
            resolution.newlyCompleted,
            to: &state.workouts
        )

        if resolution.isFinished {
            clearPlayback(&state)

            var effects: [Effect<Action>] = [
                .cancel(id: CancelID.timer),
                stopPlaybackEffect()
            ]

            if !resolution.newlyCompleted.isEmpty {
                effects.append(.send(.delegate(.workoutsChanged)))
            }

            return .merge(effects)
        }

        state.playbackSession = updatedSession
        state.isPlayingAll = resolution.presentation?.isPlayingAll ?? false
        state.isPlaybackPaused = updatedSession.isPaused
        state.activeWorkoutId = resolution.presentation?.activeItem.id
        state.activeWorkoutRemainingSeconds = resolution.presentation?.remainingSeconds
        state.playbackQueue = resolution.remainingQueue

        var effects: [Effect<Action>] = []

        if !resolution.newlyCompleted.isEmpty || previousActiveWorkoutID != state.activeWorkoutId {
            effects.append(
                updatePlaybackEffect(
                    session: updatedSession,
                    presentation: resolution.presentation
                )
            )
        }

        if !resolution.newlyCompleted.isEmpty {
            effects.append(.send(.delegate(.workoutsChanged)))
        }

        return .merge(effects)
    }

    private func startPlaybackEffect(
        session: WorkoutPlaybackSession,
        presentation: WorkoutPlaybackPresentation?
    ) -> Effect<Action> {
        let workoutPlayback = self.workoutPlayback
        return .run { _ in
            await workoutPlayback.requestAuthorization()
            await workoutPlayback.start(session, presentation)
        }
    }

    private func updatePlaybackEffect(
        session: WorkoutPlaybackSession,
        presentation: WorkoutPlaybackPresentation?
    ) -> Effect<Action> {
        let workoutPlayback = self.workoutPlayback
        return .run { _ in
            await workoutPlayback.update(session, presentation)
        }
    }

    private func stopPlaybackEffect() -> Effect<Action> {
        let workoutPlayback = self.workoutPlayback
        return .run { _ in
            await workoutPlayback.stop()
        }
    }

    private func pausePlaybackEffect() -> Effect<Action> {
        let workoutPlayback = self.workoutPlayback
        return .run { _ in
            _ = await workoutPlayback.pause()
        }
    }

    private func resumePlaybackEffect() -> Effect<Action> {
        let workoutPlayback = self.workoutPlayback
        return .run { _ in
            _ = await workoutPlayback.resume()
        }
    }

    private func pausedSession(from session: WorkoutPlaybackSession?) -> WorkoutPlaybackSession? {
        guard var session, session.pausedAt == nil else { return nil }
        session.pausedAt = Date()
        return session
    }

    private func resumedSession(from session: WorkoutPlaybackSession?) -> WorkoutPlaybackSession? {
        guard var session, let pausedAt = session.pausedAt else { return nil }
        session.accumulatedPauseDuration += max(0, Date().timeIntervalSince(pausedAt))
        session.pausedAt = nil
        return session
    }

    private func applyCompletions(
        _ completions: [WorkoutPlaybackCompletion],
        to workouts: inout [Workout]
    ) {
        for completion in completions {
            guard let index = workouts.firstIndex(where: { $0.id == completion.item.id }) else {
                continue
            }

            var workout = workouts[index]
            let wasYesterday = wasPerformedYesterday(workout.lastPerformedAt)
            workout.completedCount += 1
            workout.totalTimeSpentSeconds += Int64(completion.item.durationSeconds)
            workout.lastPerformedAt = Int64(completion.completedAt.timeIntervalSince1970 * 1_000)
            workout.currentStreak = wasYesterday ? workout.currentStreak + 1 : 1
            workouts[index] = workout
        }
    }
}
