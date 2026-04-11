import XCTest
@testable import Semaphore

final class PersistenceAndMediaStoreTests: XCTestCase {
    func testWorkoutCoreDataStoreRoundTrip() async throws {
        let directory = try makeTemporaryDirectory()
        let store = WorkoutCoreDataStore(
            configuration: WorkoutStoreConfiguration(
                persistentStoreURL: directory.appendingPathComponent("Semaphore.sqlite"),
                legacyStorageURL: nil
            )
        )

        try await store.save([
            makeWorkout(id: "second", createdAt: 2_000, seconds: 45, position: 4),
            makeWorkout(id: "first", createdAt: 1_000, seconds: 30, position: 0),
        ])

        let loaded = try await store.load()
        XCTAssertEqual(loaded.map(\.id), ["first", "second"])
        XCTAssertEqual(loaded.map(\.position), [0, 1])

        let snapshot = try await store.exportSnapshot()
        XCTAssertEqual(snapshot.workouts, loaded)
    }

    func testWorkoutCoreDataStoreMigratesLegacyJSON() async throws {
        let directory = try makeTemporaryDirectory()
        let legacyURL = directory.appendingPathComponent("workouts.json")
        let expected = [
            makeWorkout(id: "legacy", createdAt: 1_000, seconds: 20, position: 0),
        ]
        try JSONEncoder().encode(expected).write(to: legacyURL)

        let store = WorkoutCoreDataStore(
            configuration: WorkoutStoreConfiguration(
                persistentStoreURL: directory.appendingPathComponent("Semaphore.sqlite"),
                legacyStorageURL: legacyURL
            )
        )

        let loaded = try await store.load()

        XCTAssertEqual(loaded, expected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    func testWorkoutMediaStorePersistsGIFWithExpectedExtension() async throws {
        let directory = try makeTemporaryDirectory()
        let store = WorkoutMediaStore(
            configuration: WorkoutMediaStoreConfiguration(directoryURL: directory)
        )
        let data = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])

        let location = try await store.saveImportedData(data)
        let url = try XCTUnwrap(URL(string: location))

        XCTAssertEqual(url.pathExtension, "gif")
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
