import ComposableArchitecture
import SwiftUI

public struct SemaphoreRootView: View {
    let store: StoreOf<SemaphoreRootFeature>
    @Environment(\.scenePhase) private var scenePhase

    private struct ViewState: Equatable {
        var isSettingsPresented: Bool
        var isUpsertPresented: Bool
        var alertMessage: String?

        init(state: SemaphoreRootFeature.State) {
            self.isSettingsPresented = state.isSettingsPresented
            self.isUpsertPresented = state.upsert != nil
            self.alertMessage = state.alertMessage
        }
    }

    public init(
        store: StoreOf<SemaphoreRootFeature> = Store(
            initialState: SemaphoreRootFeature.State()
        ) {
            SemaphoreRootFeature()
        }
    ) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: ViewState.init(state:)) { viewStore in
            GridBackground {
                NavigationStack {
                    WorkoutListView(
                        store: store.scope(
                            state: \.workoutList,
                            action: \.workoutList
                        )
                    )
                    .navigationBarHidden(true)
                    .navigationDestination(
                        isPresented: viewStore.binding(
                            get: \.isSettingsPresented,
                            send: SemaphoreRootFeature.Action.setSettingsPresented
                        )
                    ) {
                        SettingsView(
                            store: store.scope(
                                state: \.settings,
                                action: \.settings
                            )
                        )
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
            .sheet(
                isPresented: viewStore.binding(
                    get: \.isUpsertPresented,
                    send: SemaphoreRootFeature.Action.setUpsertPresented
                )
            ) {
                if let upsertStore = store.scope(state: \.upsert, action: \.upsert) {
                    NavigationStack {
                        UpsertView(store: upsertStore)
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
            .task {
                viewStore.send(.task)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    viewStore.send(.workoutList(.refreshPlayback))
                }
            }
            .alert(
                "Notice",
                isPresented: Binding(
                    get: { viewStore.state.alertMessage != nil },
                    set: { newValue in
                        if !newValue {
                            viewStore.send(.alertDismissed)
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewStore.send(.alertDismissed)
                }
            } message: {
                Text(viewStore.state.alertMessage ?? "")
            }
        }
    }
}
