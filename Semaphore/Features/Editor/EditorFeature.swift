import ComposableArchitecture
import PhotosUI
import SwiftUI

@Reducer
public struct EditorFeature {
    @ObservableState
    public struct State: Identifiable, Equatable {
        public var workoutID: String?
        public var name = ""
        public var hours = 0
        public var minutes = 0
        public var seconds = 0
        public var currentImageLocation: String?
        public var remoteImageURL = ""
        public var selectedMediaData: Data?
        public var errorMessage: String?

        public init(workout: Workout? = nil) {
            guard let workout else { return }

            self.workoutID = workout.id
            self.name = workout.name
            self.hours = workout.hours
            self.minutes = workout.minutes
            self.seconds = workout.seconds
            self.currentImageLocation = workout.imageLocation
            self.remoteImageURL = isRemoteURL(workout.imageLocation ?? "")
                ? (workout.imageLocation ?? "")
                : ""
        }

        public var id: String {
            workoutID ?? "new-workout"
        }

        public var isEdit: Bool {
            workoutID != nil
        }

        public var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (hours + minutes + seconds) > 0
        }

        public var draft: WorkoutDraft {
            WorkoutDraft(
                workoutID: workoutID,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                hours: hours,
                minutes: minutes,
                seconds: seconds,
                currentImageLocation: currentImageLocation,
                remoteImageURL: remoteImageURL,
                selectedMediaData: selectedMediaData
            )
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case pickedMedia(Data)
        case removeMediaTapped
        case saveTapped
        case cancelTapped
        case dismissError
        case delegate(Delegate)
    }

    public enum Delegate: Equatable {
        case saveRequested(WorkoutDraft)
        case cancelRequested
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.remoteImageURL):
                if isRemoteURL(state.remoteImageURL) {
                    state.selectedMediaData = nil
                    state.currentImageLocation = nil
                }
                return .none

            case .binding:
                return .none

            case .pickedMedia(let data):
                state.selectedMediaData = data
                state.currentImageLocation = nil
                state.remoteImageURL = ""
                return .none

            case .removeMediaTapped:
                state.selectedMediaData = nil
                state.currentImageLocation = nil
                state.remoteImageURL = ""
                return .none

            case .saveTapped:
                guard state.isValid else {
                    state.errorMessage = "Enter a workout name and choose a non-zero duration."
                    return .none
                }
                return .send(.delegate(.saveRequested(state.draft)))

            case .cancelTapped:
                return .send(.delegate(.cancelRequested))

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
