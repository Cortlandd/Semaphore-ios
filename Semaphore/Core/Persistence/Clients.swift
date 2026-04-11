import ComposableArchitecture
@preconcurrency import CoreData
import Foundation

public struct WorkoutPersistenceClient: Sendable {
    public var load: @Sendable () async throws -> [Workout]
    public var save: @Sendable ([Workout]) async throws -> Void
    public var exportSnapshot: @Sendable () async throws -> WorkoutLibrarySnapshot

    public init(
        load: @escaping @Sendable () async throws -> [Workout] = { [] },
        save: @escaping @Sendable ([Workout]) async throws -> Void = { _ in },
        exportSnapshot: @escaping @Sendable () async throws -> WorkoutLibrarySnapshot = {
            WorkoutLibrarySnapshot(workouts: [])
        }
    ) {
        self.load = load
        self.save = save
        self.exportSnapshot = exportSnapshot
    }
}

extension WorkoutPersistenceClient: DependencyKey {
    public static let liveValue = Self(
        load: {
            try await WorkoutCoreDataStore.shared.load()
        },
        save: { workouts in
            try await WorkoutCoreDataStore.shared.save(workouts)
        },
        exportSnapshot: {
            try await WorkoutCoreDataStore.shared.exportSnapshot()
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var workoutPersistence: WorkoutPersistenceClient {
        get { self[WorkoutPersistenceClient.self] }
        set { self[WorkoutPersistenceClient.self] = newValue }
    }
}

public struct WorkoutMediaStoreClient: Sendable {
    public var saveImportedData: @Sendable (Data) async throws -> String

    public init(
        saveImportedData: @escaping @Sendable (Data) async throws -> String = { _ in
            URL(fileURLWithPath: "/dev/null").absoluteString
        }
    ) {
        self.saveImportedData = saveImportedData
    }
}

extension WorkoutMediaStoreClient: DependencyKey {
    public static let liveValue = Self(
        saveImportedData: { data in
            try await WorkoutMediaStore.shared.saveImportedData(data)
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var workoutMediaStore: WorkoutMediaStoreClient {
        get { self[WorkoutMediaStoreClient.self] }
        set { self[WorkoutMediaStoreClient.self] = newValue }
    }
}

public enum AppMetadata {
    public static var versionString: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
    }

    public static var buildString: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
    }

    public static var displayVersion: String {
        "\(versionString) (\(buildString))"
    }
}

struct WorkoutStoreConfiguration: Sendable {
    var persistentStoreURL: URL
    var legacyStorageURL: URL?

    static func live() throws -> Self {
        Self(
            persistentStoreURL: try appSupportDirectory()
                .appendingPathComponent("Semaphore.sqlite", isDirectory: false),
            legacyStorageURL: try appSupportDirectory()
                .appendingPathComponent("workouts.json", isDirectory: false)
        )
    }
}

actor WorkoutCoreDataStore {
    static let shared = WorkoutCoreDataStore()

    private let configuration: WorkoutStoreConfiguration
    private let containerTask: Task<NSPersistentContainer, Error>

    init(configuration: WorkoutStoreConfiguration? = nil) {
        let resolvedConfiguration = configuration ?? (try? WorkoutStoreConfiguration.live()) ?? WorkoutStoreConfiguration(
            persistentStoreURL: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("Semaphore.sqlite", isDirectory: false),
            legacyStorageURL: nil
        )
        self.configuration = resolvedConfiguration
        self.containerTask = Task {
            try await Self.makePersistentContainer(configuration: resolvedConfiguration)
        }
    }

    func load() async throws -> [Workout] {
        let container = try await containerTask.value

        return try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<[Workout], Error>
        ) in
            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
                    request.sortDescriptors = [
                        NSSortDescriptor(key: WorkoutProperty.position.rawValue, ascending: true),
                        NSSortDescriptor(key: WorkoutProperty.createdAt.rawValue, ascending: true),
                    ]
                    request.returnsObjectsAsFaults = false

                    let objects = try context.fetch(request)
                    continuation.resume(returning: Self.normalize(objects.map(Self.makeWorkout)))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func save(_ workouts: [Workout]) async throws {
        let container = try await containerTask.value
        let normalized = Self.normalize(workouts)

        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, Error>
        ) in
            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
                    request.returnsObjectsAsFaults = false

                    let existingObjects = try context.fetch(request)
                    var objectsByID = Dictionary(
                        uniqueKeysWithValues: existingObjects.compactMap { object -> (String, NSManagedObject)? in
                            guard let id = object.value(forKey: WorkoutProperty.id.rawValue) as? String else {
                                return nil
                            }

                            return (id, object)
                        }
                    )

                    for workout in normalized {
                        let object = objectsByID.removeValue(forKey: workout.id)
                            ?? NSEntityDescription.insertNewObject(
                                forEntityName: Self.entityName,
                                into: context
                            )
                        Self.update(object, with: workout)
                    }

                    for object in objectsByID.values {
                        context.delete(object)
                    }

                    if context.hasChanges {
                        try context.save()
                    }

                    continuation.resume(returning: ())
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func exportSnapshot() async throws -> WorkoutLibrarySnapshot {
        WorkoutLibrarySnapshot(workouts: try await load())
    }

    private static let entityName = "WorkoutEntity"

    private enum WorkoutProperty: String, CaseIterable {
        case id
        case createdAt
        case name
        case imageLocation
        case hours
        case minutes
        case seconds
        case position
        case orderId
        case completedCount
        case totalTimeSpentSeconds
        case lastPerformedAt
        case currentStreak
    }

    private static func makePersistentContainer(
        configuration: WorkoutStoreConfiguration
    ) async throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: "SemaphoreWorkouts",
            managedObjectModel: managedObjectModel()
        )

        let description = NSPersistentStoreDescription(url: configuration.persistentStoreURL)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        description.shouldAddStoreAsynchronously = true
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, Error>
        ) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        try await migrateLegacyJSONIfNeeded(
            in: container,
            legacyURL: configuration.legacyStorageURL
        )
        return container
    }

    private static func migrateLegacyJSONIfNeeded(
        in container: NSPersistentContainer,
        legacyURL: URL?
    ) async throws {
        guard let legacyURL else { return }
        guard FileManager.default.fileExists(atPath: legacyURL.path()) else {
            return
        }

        let hasExistingRecords = try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Bool, Error>
        ) in
            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    request.fetchLimit = 1
                    let count = try context.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard !hasExistingRecords else { return }

        let data = try Data(contentsOf: legacyURL)
        let workouts = try JSONDecoder().decode([Workout].self, from: data)
        let normalized = normalize(workouts)

        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, Error>
        ) in
            container.performBackgroundTask { context in
                do {
                    for workout in normalized {
                        let object = NSEntityDescription.insertNewObject(
                            forEntityName: entityName,
                            into: context
                        )
                        update(object, with: workout)
                    }

                    if context.hasChanges {
                        try context.save()
                    }

                    try? FileManager.default.removeItem(at: legacyURL)
                    continuation.resume(returning: ())
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func managedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        entity.properties = [
            attribute(.id, type: .stringAttributeType),
            attribute(.createdAt, type: .integer64AttributeType),
            attribute(.name, type: .stringAttributeType),
            attribute(.imageLocation, type: .stringAttributeType, isOptional: true),
            attribute(.hours, type: .integer16AttributeType),
            attribute(.minutes, type: .integer16AttributeType),
            attribute(.seconds, type: .integer16AttributeType),
            attribute(.position, type: .integer32AttributeType),
            attribute(.orderId, type: .integer32AttributeType),
            attribute(.completedCount, type: .integer32AttributeType),
            attribute(.totalTimeSpentSeconds, type: .integer64AttributeType),
            attribute(.lastPerformedAt, type: .integer64AttributeType, isOptional: true),
            attribute(.currentStreak, type: .integer32AttributeType),
        ]
        entity.uniquenessConstraints = [[WorkoutProperty.id.rawValue]]

        model.entities = [entity]
        return model
    }

    private static func attribute(
        _ property: WorkoutProperty,
        type: NSAttributeType,
        isOptional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = property.rawValue
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }

    private static func normalize(_ workouts: [Workout]) -> [Workout] {
        workouts
            .sorted { lhs, rhs in
                if lhs.position == rhs.position {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.position < rhs.position
            }
            .enumerated()
            .map { index, workout in
                var normalizedWorkout = workout
                normalizedWorkout.position = index
                return normalizedWorkout
            }
    }

    private static func makeWorkout(from object: NSManagedObject) -> Workout {
        Workout(
            id: stringValue(.id, from: object),
            createdAt: int64Value(.createdAt, from: object),
            name: stringValue(.name, from: object),
            imageLocation: optionalStringValue(.imageLocation, from: object),
            hours: intValue(.hours, from: object),
            minutes: intValue(.minutes, from: object),
            seconds: intValue(.seconds, from: object),
            position: intValue(.position, from: object),
            orderId: intValue(.orderId, from: object),
            completedCount: intValue(.completedCount, from: object),
            totalTimeSpentSeconds: int64Value(.totalTimeSpentSeconds, from: object),
            lastPerformedAt: optionalInt64Value(.lastPerformedAt, from: object),
            currentStreak: intValue(.currentStreak, from: object)
        )
    }

    private static func update(_ object: NSManagedObject, with workout: Workout) {
        object.setValue(workout.id, forKey: WorkoutProperty.id.rawValue)
        object.setValue(workout.createdAt, forKey: WorkoutProperty.createdAt.rawValue)
        object.setValue(workout.name, forKey: WorkoutProperty.name.rawValue)
        object.setValue(workout.imageLocation, forKey: WorkoutProperty.imageLocation.rawValue)
        object.setValue(workout.hours, forKey: WorkoutProperty.hours.rawValue)
        object.setValue(workout.minutes, forKey: WorkoutProperty.minutes.rawValue)
        object.setValue(workout.seconds, forKey: WorkoutProperty.seconds.rawValue)
        object.setValue(workout.position, forKey: WorkoutProperty.position.rawValue)
        object.setValue(workout.orderId, forKey: WorkoutProperty.orderId.rawValue)
        object.setValue(workout.completedCount, forKey: WorkoutProperty.completedCount.rawValue)
        object.setValue(
            workout.totalTimeSpentSeconds,
            forKey: WorkoutProperty.totalTimeSpentSeconds.rawValue
        )
        object.setValue(workout.lastPerformedAt, forKey: WorkoutProperty.lastPerformedAt.rawValue)
        object.setValue(workout.currentStreak, forKey: WorkoutProperty.currentStreak.rawValue)
    }

    private static func stringValue(_ property: WorkoutProperty, from object: NSManagedObject) -> String {
        object.value(forKey: property.rawValue) as? String ?? ""
    }

    private static func optionalStringValue(
        _ property: WorkoutProperty,
        from object: NSManagedObject
    ) -> String? {
        object.value(forKey: property.rawValue) as? String
    }

    private static func intValue(_ property: WorkoutProperty, from object: NSManagedObject) -> Int {
        (object.value(forKey: property.rawValue) as? NSNumber)?.intValue ?? 0
    }

    private static func int64Value(_ property: WorkoutProperty, from object: NSManagedObject) -> Int64 {
        (object.value(forKey: property.rawValue) as? NSNumber)?.int64Value ?? 0
    }

    private static func optionalInt64Value(
        _ property: WorkoutProperty,
        from object: NSManagedObject
    ) -> Int64? {
        (object.value(forKey: property.rawValue) as? NSNumber)?.int64Value
    }
}

func appSupportDirectory() throws -> URL {
    let directory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("Semaphore", isDirectory: true)

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    return directory
}

struct WorkoutMediaStoreConfiguration: Sendable {
    var directoryURL: URL

    static func live() throws -> Self {
        Self(directoryURL: try appSupportDirectory().appendingPathComponent("workout_media", isDirectory: true))
    }
}

actor WorkoutMediaStore {
    static let shared = WorkoutMediaStore()

    private let configuration: WorkoutMediaStoreConfiguration

    init(configuration: WorkoutMediaStoreConfiguration? = nil) {
        self.configuration = configuration ?? (try? WorkoutMediaStoreConfiguration.live()) ?? WorkoutMediaStoreConfiguration(
            directoryURL: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("Semaphore/workout_media", isDirectory: true)
        )
    }

    func saveImportedData(_ data: Data) throws -> String {
        let directory = try Self.mediaDirectoryURL(configuration: configuration)
        let fileExtension = Self.fileExtension(for: data)
        let fileURL = directory.appendingPathComponent(
            UUID().uuidString.appending(fileExtension.map { ".\($0)" } ?? ""),
            isDirectory: false
        )

        try data.write(to: fileURL, options: [.atomic])
        return fileURL.absoluteString
    }

    private static func mediaDirectoryURL(
        configuration: WorkoutMediaStoreConfiguration
    ) throws -> URL {
        let directory = configuration.directoryURL
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    private static func fileExtension(for data: Data) -> String? {
        if data.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        return nil
    }
}
