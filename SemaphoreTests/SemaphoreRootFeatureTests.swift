import ComposableArchitecture
import XCTest
@testable import Semaphore

@MainActor
final class SemaphoreRootFeatureTests: XCTestCase {
    func testTaskLoadsWorkoutsAndRefreshesPlayback() async {
        let workouts = [
            makeWorkout(id: "first", seconds: 30, position: 0),
            makeWorkout(id: "second", seconds: 45, position: 1),
        ]

        let store = TestStore(initialState: SemaphoreRootFeature.State()) {
            SemaphoreRootFeature()
        }
        store.dependencies.workoutPersistence.load = { workouts }
        store.dependencies.workoutPlayback.restore = { nil }

        await store.send(.task)
        await store.receive(.workoutsLoaded(workouts)) {
            $0.workoutList.workouts = workouts
            $0.workoutList.displayMode = .content
            $0.workoutList.error = nil
            $0.settings.workouts = workouts
        }
        await store.receive(.workoutList(.refreshPlayback))
        await store.receive(.workoutList(.playbackRestored(nil)))
    }

    func testTaskFailureSurfacesAlert() async {
        let store = TestStore(initialState: SemaphoreRootFeature.State()) {
            SemaphoreRootFeature()
        }
        store.dependencies.workoutPersistence.load = {
            throw NSError(
                domain: "SemaphoreTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Load failed"]
            )
        }

        await store.send(.task)
        await store.receive(.workoutsLoadFailed("Load failed")) {
            $0.workoutList.displayMode = .error
            $0.workoutList.error = "Load failed"
            $0.settings.workouts = []
            $0.alertMessage = "Load failed"
        }
    }

    func testSaveRequestedUpdatesWorkoutAndPersists() async {
        let recorder = SaveRecorder()
        let existingWorkout = makeWorkout(
            id: "first",
            name: "Old Name",
            imageLocation: nil,
            minutes: 1,
            position: 0
        )

        var initialState = SemaphoreRootFeature.State()
        initialState.workoutList.workouts = [existingWorkout]
        initialState.workoutList.displayMode = .content
        initialState.settings.workouts = [existingWorkout]
        initialState.upsert = UpsertFeature.State(workout: existingWorkout)

        let store = TestStore(initialState: initialState) {
            SemaphoreRootFeature()
        }
        store.dependencies.workoutMediaStore.saveImportedData = { _ in
            "file:///tmp/updated.gif"
        }
        store.dependencies.workoutPersistence.save = { workouts in
            await recorder.record(workouts)
        }

        let draft = WorkoutDraft(
            workoutID: existingWorkout.id,
            name: "Updated Name",
            hours: 0,
            minutes: 2,
            seconds: 15,
            currentImageLocation: nil,
            remoteImageURL: "",
            selectedMediaData: Data([0x47, 0x49, 0x46, 0x38])
        )

        await store.send(.upsert(.delegate(.saveRequested(draft))))
        await store.receive(
            .upsertSaveCompleted(
                makeWorkout(
                    id: existingWorkout.id,
                    createdAt: existingWorkout.createdAt,
                    name: "Updated Name",
                    imageLocation: "file:///tmp/updated.gif",
                    hours: 0,
                    minutes: 2,
                    seconds: 15,
                    position: 0,
                    orderId: existingWorkout.orderId
                )
            )
        ) {
            $0.workoutList.workouts[0].name = "Updated Name"
            $0.workoutList.workouts[0].imageLocation = "file:///tmp/updated.gif"
            $0.workoutList.workouts[0].hours = 0
            $0.workoutList.workouts[0].minutes = 2
            $0.workoutList.workouts[0].seconds = 15
            $0.workoutList.displayMode = .content
            $0.upsert = nil
            $0.settings.workouts = $0.workoutList.workouts
        }

        await store.finish()

        let savedWorkouts = await recorder.lastSnapshot()
        XCTAssertEqual(savedWorkouts?.first?.name, "Updated Name")
        XCTAssertEqual(savedWorkouts?.first?.imageLocation, "file:///tmp/updated.gif")
    }
}
