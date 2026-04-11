import ComposableArchitecture
import SwiftUI

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var version: String
        public var workouts: [Workout] = []

        public init(version: String, workouts: [Workout] = []) {
            self.version = version
            self.workouts = workouts
        }
    }

    public enum Action: Equatable {
        case rateTapped
        case removeAdsTapped
        case restoreTapped
        case delegate(Delegate)
    }

    public enum Delegate: Equatable {
        case showMessage(String)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .rateTapped:
                return .send(
                    .delegate(
                        .showMessage("Add your App Store review URL to wire up the Rate App action.")
                    )
                )

            case .removeAdsTapped:
                return .send(
                    .delegate(
                        .showMessage("Remove Ads is not connected on iOS yet.")
                    )
                )

            case .restoreTapped:
                return .send(
                    .delegate(
                        .showMessage("Restore Purchases is not connected on iOS yet.")
                    )
                )

            case .delegate:
                return .none
            }
        }
    }
}
