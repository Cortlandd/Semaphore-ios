import ComposableArchitecture
import SwiftUI

@Reducer
public struct SemaphoreRootFeature {
    @ObservableState
    public struct State: Equatable {
        public var workoutList = WorkoutListFeature.State()
        public var editor: EditorFeature.State?
        public var isSettingsPresented = false
        public var settings = SettingsFeature.State(version: AppMetadata.displayVersion)
        public var alertMessage: String?

        public init() {}
    }

    public enum Action: Equatable {
        case task
        case workoutsLoaded([Workout])
        case workoutsLoadFailed(String)
        case workoutsPersistFailed(String)
        case workoutList(WorkoutListFeature.Action)
        case editor(EditorFeature.Action)
        case editorSaveCompleted(Workout)
        case editorSaveFailed(String)
        case setEditorPresented(Bool)
        case setSettingsPresented(Bool)
        case settings(SettingsFeature.Action)
        case alertDismissed
    }

    @Dependency(\.workoutPersistence) var workoutPersistence
    @Dependency(\.workoutMediaStore) var workoutMediaStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.workoutList, action: \.workoutList) {
            WorkoutListFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                let workoutPersistence = self.workoutPersistence
                return .run { send in
                    do {
                        let workouts = try await workoutPersistence.load()
                        await send(.workoutsLoaded(workouts))
                    } catch {
                        await send(.workoutsLoadFailed(error.localizedDescription))
                    }
                }

            case .workoutsLoaded(let workouts):
                state.workoutList.workouts = workouts
                state.workoutList.displayMode = workouts.isEmpty ? .empty : .content
                state.workoutList.error = nil
                state.settings.workouts = workouts
                return .send(.workoutList(.refreshPlayback))

            case .workoutsLoadFailed(let message):
                state.workoutList.displayMode = .error
                state.workoutList.error = message
                state.settings.workouts = []
                state.alertMessage = message
                return .none

            case .workoutsPersistFailed(let message):
                state.alertMessage = message
                syncSettings(from: &state)
                return .none

            case .workoutList(.delegate(.addWorkoutRequested)):
                state.editor = EditorFeature.State()
                syncSettings(from: &state)
                return .none

            case .workoutList(.delegate(.editWorkoutRequested(let workoutID))):
                guard let workout = state.workoutList.workouts.first(where: { $0.id == workoutID }) else {
                    state.alertMessage = "Unable to find that workout."
                    syncSettings(from: &state)
                    return .none
                }

                state.editor = EditorFeature.State(workout: workout)
                syncSettings(from: &state)
                return .none

            case .workoutList(.delegate(.settingsRequested)):
                state.isSettingsPresented = true
                syncSettings(from: &state)
                return .none

            case .workoutList(.delegate(.workoutsChanged)):
                syncSettings(from: &state)
                return persistWorkouts(
                    state.workoutList.workouts,
                    workoutPersistence: workoutPersistence
                )

            case .editor(.delegate(.cancelRequested)):
                state.editor = nil
                syncSettings(from: &state)
                return .none

            case .editor(.delegate(.saveRequested(let draft))):
                let existingWorkout = draft.workoutID.flatMap { workoutID in
                    state.workoutList.workouts.first(where: { $0.id == workoutID })
                }
                let workoutMediaStore = self.workoutMediaStore
                let currentCount = state.workoutList.workouts.count

                return .run { send in
                    do {
                        let imageLocation = try await Self.resolveImageLocation(
                            draft: draft,
                            workoutMediaStore: workoutMediaStore
                        )

                        let workout = Self.buildWorkout(
                            draft: draft,
                            existingWorkout: existingWorkout,
                            imageLocation: imageLocation,
                            currentCount: currentCount
                        )

                        await send(.editorSaveCompleted(workout))
                    } catch {
                        await send(.editorSaveFailed(error.localizedDescription))
                    }
                }

            case .editorSaveCompleted(let workout):
                if let existingIndex = state.workoutList.workouts.firstIndex(where: { $0.id == workout.id }) {
                    state.workoutList.workouts[existingIndex] = workout
                } else {
                    state.workoutList.workouts.append(workout)
                }

                state.workoutList.workouts.sort { $0.position < $1.position }
                for index in state.workoutList.workouts.indices {
                    state.workoutList.workouts[index].position = index
                }

                state.workoutList.displayMode = state.workoutList.workouts.isEmpty ? .empty : .content
                state.editor = nil
                syncSettings(from: &state)
                return persistWorkouts(
                    state.workoutList.workouts,
                    workoutPersistence: workoutPersistence
                )

            case .editorSaveFailed(let message):
                state.alertMessage = message
                syncSettings(from: &state)
                return .none

            case .setEditorPresented(let isPresented):
                if !isPresented {
                    state.editor = nil
                }
                syncSettings(from: &state)
                return .none

            case .setSettingsPresented(let isPresented):
                state.isSettingsPresented = isPresented
                syncSettings(from: &state)
                return .none

            case .settings(.delegate(.showMessage(let message))):
                state.alertMessage = message
                syncSettings(from: &state)
                return .none

            case .alertDismissed:
                state.alertMessage = nil
                syncSettings(from: &state)
                return .none

            case .editor, .settings, .workoutList:
                syncSettings(from: &state)
                return .none
            }
        }
        .ifLet(\.editor, action: \.editor) {
            EditorFeature()
        }
    }

    private func persistWorkouts(
        _ workouts: [Workout],
        workoutPersistence: WorkoutPersistenceClient
    ) -> Effect<Action> {
        .run { send in
            do {
                try await workoutPersistence.save(workouts)
            } catch {
                await send(.workoutsPersistFailed(error.localizedDescription))
            }
        }
    }

    private func syncSettings(from state: inout State) {
        state.settings.workouts = state.workoutList.workouts
    }

    private static func resolveImageLocation(
        draft: WorkoutDraft,
        workoutMediaStore: WorkoutMediaStoreClient
    ) async throws -> String? {
        if let selectedMediaData = draft.selectedMediaData, !selectedMediaData.isEmpty {
            return try await workoutMediaStore.saveImportedData(selectedMediaData)
        }

        let trimmedRemoteURL = draft.remoteImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRemoteURL(trimmedRemoteURL) {
            return trimmedRemoteURL
        }

        return draft.currentImageLocation
    }

    private static func buildWorkout(
        draft: WorkoutDraft,
        existingWorkout: Workout?,
        imageLocation: String?,
        currentCount: Int
    ) -> Workout {
        if let existingWorkout {
            var updatedWorkout = existingWorkout
            updatedWorkout.name = draft.name
            updatedWorkout.hours = draft.hours
            updatedWorkout.minutes = draft.minutes
            updatedWorkout.seconds = draft.seconds
            updatedWorkout.imageLocation = imageLocation
            return updatedWorkout
        }

        return Workout(
            id: UUID().uuidString,
            createdAt: Int64(Date().timeIntervalSince1970 * 1_000),
            name: draft.name,
            imageLocation: imageLocation,
            hours: draft.hours,
            minutes: draft.minutes,
            seconds: draft.seconds,
            position: currentCount,
            orderId: 0
        )
    }
}
