@preconcurrency import ActivityKit
import AVFoundation
import ComposableArchitecture
import Foundation
import ImageIO
import UIKit
import UserNotifications

public struct WorkoutPlaybackSession: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var imageLocation: String?
        public var durationSeconds: Int

        public init(
            id: String,
            name: String,
            imageLocation: String?,
            durationSeconds: Int
        ) {
            self.id = id
            self.name = name
            self.imageLocation = imageLocation
            self.durationSeconds = durationSeconds
        }
    }

    public var startedAt: Date
    public var items: [Item]
    public var isPlayingAll: Bool
    public var appliedCompletionCount: Int
    public var pausedAt: Date?
    public var accumulatedPauseDuration: TimeInterval

    public init(
        startedAt: Date,
        items: [Item],
        isPlayingAll: Bool,
        appliedCompletionCount: Int = 0,
        pausedAt: Date? = nil,
        accumulatedPauseDuration: TimeInterval = 0
    ) {
        self.startedAt = startedAt
        self.items = items
        self.isPlayingAll = isPlayingAll
        self.appliedCompletionCount = appliedCompletionCount
        self.pausedAt = pausedAt
        self.accumulatedPauseDuration = accumulatedPauseDuration
    }

    enum CodingKeys: String, CodingKey {
        case startedAt
        case items
        case isPlayingAll
        case appliedCompletionCount
        case pausedAt
        case accumulatedPauseDuration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.items = try container.decode([Item].self, forKey: .items)
        self.isPlayingAll = try container.decode(Bool.self, forKey: .isPlayingAll)
        self.appliedCompletionCount = try container.decodeIfPresent(
            Int.self,
            forKey: .appliedCompletionCount
        ) ?? 0
        self.pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        self.accumulatedPauseDuration = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .accumulatedPauseDuration
        ) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(items, forKey: .items)
        try container.encode(isPlayingAll, forKey: .isPlayingAll)
        try container.encode(appliedCompletionCount, forKey: .appliedCompletionCount)
        try container.encodeIfPresent(pausedAt, forKey: .pausedAt)
        try container.encode(accumulatedPauseDuration, forKey: .accumulatedPauseDuration)
    }

    public var isPaused: Bool {
        pausedAt != nil
    }
}

public struct WorkoutPlaybackCompletion: Equatable, Sendable {
    public var item: WorkoutPlaybackSession.Item
    public var completedAt: Date
}

public struct WorkoutPlaybackPresentation: Equatable, Sendable {
    public var activeItem: WorkoutPlaybackSession.Item
    public var timerRange: ClosedRange<Date>
    public var remainingSeconds: Int
    public var isPlayingAll: Bool
    public var remainingQueueCount: Int
    public var isPaused: Bool

    public init(
        activeItem: WorkoutPlaybackSession.Item,
        timerRange: ClosedRange<Date>,
        remainingSeconds: Int,
        isPlayingAll: Bool,
        remainingQueueCount: Int,
        isPaused: Bool
    ) {
        self.activeItem = activeItem
        self.timerRange = timerRange
        self.remainingSeconds = remainingSeconds
        self.isPlayingAll = isPlayingAll
        self.remainingQueueCount = remainingQueueCount
        self.isPaused = isPaused
    }
}

public struct WorkoutPlaybackResolution: Equatable, Sendable {
    public var presentation: WorkoutPlaybackPresentation?
    public var completedCount: Int
    public var newlyCompleted: [WorkoutPlaybackCompletion]
    public var isFinished: Bool
    public var remainingQueue: [String]

    public init(
        presentation: WorkoutPlaybackPresentation?,
        completedCount: Int,
        newlyCompleted: [WorkoutPlaybackCompletion],
        isFinished: Bool,
        remainingQueue: [String]
    ) {
        self.presentation = presentation
        self.completedCount = completedCount
        self.newlyCompleted = newlyCompleted
        self.isFinished = isFinished
        self.remainingQueue = remainingQueue
    }
}

public func resolvePlayback(
    session: WorkoutPlaybackSession,
    now: Date = Date()
) -> WorkoutPlaybackResolution {
    guard !session.items.isEmpty else {
        return WorkoutPlaybackResolution(
            presentation: nil,
            completedCount: 0,
            newlyCompleted: [],
            isFinished: true,
            remainingQueue: []
        )
    }

    let playbackNow = session.pausedAt ?? now
    let elapsed = max(
        0,
        playbackNow.timeIntervalSince(session.startedAt) - session.accumulatedPauseDuration
    )
    var completedCount = 0
    var cumulative: TimeInterval = 0
    var newlyCompleted: [WorkoutPlaybackCompletion] = []

    for (index, item) in session.items.enumerated() {
        let itemDuration = TimeInterval(max(item.durationSeconds, 1))
        let end = cumulative + itemDuration

        if elapsed >= end {
            completedCount += 1

            if index >= session.appliedCompletionCount {
                newlyCompleted.append(
                    WorkoutPlaybackCompletion(
                        item: item,
                        completedAt: session.startedAt.addingTimeInterval(end)
                    )
                )
            }
            cumulative = end
            continue
        }

        let activeStart = session.startedAt.addingTimeInterval(
            cumulative + session.accumulatedPauseDuration
        )
        let activeEnd = activeStart.addingTimeInterval(itemDuration)
        let elapsedInCurrent = max(0, elapsed - cumulative)
        let remaining = max(Int(ceil(itemDuration - elapsedInCurrent)), 1)
        let remainingQueue = session.items.dropFirst(index + 1).map(\.id)

        return WorkoutPlaybackResolution(
            presentation: WorkoutPlaybackPresentation(
                activeItem: item,
                timerRange: activeStart...activeEnd,
                remainingSeconds: remaining,
                isPlayingAll: session.isPlayingAll,
                remainingQueueCount: remainingQueue.count,
                isPaused: session.isPaused
            ),
            completedCount: completedCount,
            newlyCompleted: newlyCompleted,
            isFinished: false,
            remainingQueue: Array(remainingQueue)
        )
    }

    return WorkoutPlaybackResolution(
        presentation: nil,
        completedCount: completedCount,
        newlyCompleted: newlyCompleted,
        isFinished: true,
        remainingQueue: []
    )
}

public struct WorkoutPlaybackClient: Sendable {
    public var requestAuthorization: @Sendable () async -> Void
    public var restore: @Sendable () async -> WorkoutPlaybackSession?
    public var start: @Sendable (WorkoutPlaybackSession, WorkoutPlaybackPresentation?) async -> Void
    public var update: @Sendable (WorkoutPlaybackSession, WorkoutPlaybackPresentation?) async -> Void
    public var pause: @Sendable () async -> WorkoutPlaybackSession?
    public var resume: @Sendable () async -> WorkoutPlaybackSession?
    public var stop: @Sendable () async -> Void
}

extension WorkoutPlaybackClient: DependencyKey {
    public static let liveValue = Self(
        requestAuthorization: {
            await WorkoutPlaybackCoordinator.shared.requestAuthorizationIfNeeded()
        },
        restore: {
            await WorkoutPlaybackCoordinator.shared.restoreSession()
        },
        start: { session, presentation in
            await WorkoutPlaybackCoordinator.shared.start(
                session: session,
                presentation: presentation
            )
        },
        update: { session, presentation in
            await WorkoutPlaybackCoordinator.shared.update(
                session: session,
                presentation: presentation
            )
        },
        pause: {
            await WorkoutPlaybackCoordinator.shared.pause()
        },
        resume: {
            await WorkoutPlaybackCoordinator.shared.resume()
        },
        stop: {
            await WorkoutPlaybackCoordinator.shared.stop()
        }
    )

    public static let testValue = Self(
        requestAuthorization: {},
        restore: { nil },
        start: { _, _ in },
        update: { _, _ in },
        pause: { nil },
        resume: { nil },
        stop: {}
    )
}

public extension DependencyValues {
    var workoutPlayback: WorkoutPlaybackClient {
        get { self[WorkoutPlaybackClient.self] }
        set { self[WorkoutPlaybackClient.self] = newValue }
    }
}

actor WorkoutPlaybackCoordinator {
    static let shared = WorkoutPlaybackCoordinator()

    private let defaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "semaphore.playback.session"
    private let liveActivityIDKey = "semaphore.playback.live_activity_id"
    private let notificationPrefix = "semaphore.playback.notification."
    private let statusNotificationIdentifier = "semaphore.playback.notification.status"
    private let activeNotificationCategory = "semaphore.playback.category.active"
    private let pausedNotificationCategory = "semaphore.playback.category.paused"
    private let pauseActionIdentifier = "semaphore.playback.action.pause"
    private let playActionIdentifier = "semaphore.playback.action.play"
    private let stopActionIdentifier = "semaphore.playback.action.stop"
    private var bellPlayer: AVAudioPlayer?

    func configureNotifications() {
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(
                identifier: activeNotificationCategory,
                actions: [
                    UNNotificationAction(identifier: pauseActionIdentifier, title: "Pause"),
                    UNNotificationAction(
                        identifier: stopActionIdentifier,
                        title: "Stop",
                        options: [.destructive]
                    )
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: pausedNotificationCategory,
                actions: [
                    UNNotificationAction(identifier: playActionIdentifier, title: "Play"),
                    UNNotificationAction(
                        identifier: stopActionIdentifier,
                        title: "Stop",
                        options: [.destructive]
                    )
                ],
                intentIdentifiers: []
            )
        ])
    }

    func requestAuthorizationIfNeeded() async {
        configureNotifications()
        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func restoreSession() async -> WorkoutPlaybackSession? {
        guard let data = defaults.data(forKey: sessionKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WorkoutPlaybackSession.self, from: data)
    }

    func start(
        session: WorkoutPlaybackSession,
        presentation: WorkoutPlaybackPresentation?
    ) async {
        let previousSession = storedSession()
        persist(session: session)
        await playBellIfNeeded(previousSession: previousSession, updatedSession: session)
        await scheduleNotifications(for: session)
        await publishStatusNotification(for: session, presentation: presentation)
        await updateLiveActivity(presentation: presentation)
    }

    func update(
        session: WorkoutPlaybackSession,
        presentation: WorkoutPlaybackPresentation?
    ) async {
        let previousSession = storedSession()
        persist(session: session)
        await playBellIfNeeded(previousSession: previousSession, updatedSession: session)
        await scheduleNotifications(for: session)
        await publishStatusNotification(for: session, presentation: presentation)
        await updateLiveActivity(presentation: presentation)
    }

    func pause() async -> WorkoutPlaybackSession? {
        guard var session = storedSession(), session.pausedAt == nil else {
            return storedSession()
        }

        session.pausedAt = Date()
        persist(session: session)

        let resolution = resolvePlayback(session: session, now: session.pausedAt ?? Date())
        await scheduleNotifications(for: session)
        await publishStatusNotification(for: session, presentation: resolution.presentation)
        await updateLiveActivity(presentation: resolution.presentation)
        return session
    }

    func resume() async -> WorkoutPlaybackSession? {
        guard var session = storedSession(), let pausedAt = session.pausedAt else {
            return storedSession()
        }

        session.accumulatedPauseDuration += max(0, Date().timeIntervalSince(pausedAt))
        session.pausedAt = nil
        persist(session: session)

        let resolution = resolvePlayback(session: session)
        await scheduleNotifications(for: session)
        await publishStatusNotification(for: session, presentation: resolution.presentation)
        await updateLiveActivity(presentation: resolution.presentation)
        return session
    }

    func stop() async {
        defaults.removeObject(forKey: sessionKey)
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: pendingNotificationIdentifiers()
        )
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [statusNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: pendingNotificationIdentifiers()
        )
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [statusNotificationIdentifier])
        await endLiveActivity()
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case pauseActionIdentifier:
            _ = await pause()
        case playActionIdentifier:
            _ = await resume()
        case stopActionIdentifier:
            await stop()
        default:
            break
        }
    }

    func publishStatusNotificationIfNeeded() async {
        guard let session = storedSession() else { return }
        let resolution = resolvePlayback(session: session)
        await publishStatusNotification(for: session, presentation: resolution.presentation)
    }

    func dismissStatusNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [statusNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [statusNotificationIdentifier])
    }

    private func persist(session: WorkoutPlaybackSession) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: sessionKey)
    }

    private func storedSession() -> WorkoutPlaybackSession? {
        guard let data = defaults.data(forKey: sessionKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WorkoutPlaybackSession.self, from: data)
    }

    private func playBellIfNeeded(
        previousSession: WorkoutPlaybackSession?,
        updatedSession: WorkoutPlaybackSession
    ) async {
        let previousCompletionCount = previousSession?.appliedCompletionCount ?? 0
        guard updatedSession.appliedCompletionCount > previousCompletionCount else {
            return
        }

        let isAppActive = await MainActor.run {
            UIApplication.shared.applicationState == .active
        }
        guard isAppActive else { return }

        playBell()
    }

    private func playBell() {
        guard let url = Bundle.main.url(forResource: "bell", withExtension: "wav") else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, options: [.mixWithOthers])
            try audioSession.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            bellPlayer = player
        } catch {
            bellPlayer = nil
        }
    }

    private func pendingNotificationIdentifiers() -> [String] {
        (0..<64).map { "\(notificationPrefix)\($0)" }
    }

    private func scheduleNotifications(for session: WorkoutPlaybackSession) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: pendingNotificationIdentifiers()
        )

        guard !session.isPaused else { return }

        var cumulative: TimeInterval = 0

        for (index, item) in session.items.enumerated() {
            cumulative += TimeInterval(max(item.durationSeconds, 1))

            let triggerDate = session.startedAt.addingTimeInterval(cumulative)
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound(named: UNNotificationSoundName("bell.wav"))
            content.categoryIdentifier = activeNotificationCategory

            if index + 1 < session.items.count {
                let nextItem = session.items[index + 1]
                content.title = "\(item.name) finished"
                content.body = "Starting \(nextItem.name)"

                if let attachment = await notificationAttachment(
                    imageLocation: nextItem.imageLocation,
                    identifier: "next-\(index)"
                ) {
                    content.attachments = [attachment]
                }
            } else {
                content.title = session.isPlayingAll ? "Routine complete" : "\(item.name) finished"
                content.body = session.isPlayingAll
                    ? "All workout timers finished."
                    : "Workout timer finished."

                if let attachment = await notificationAttachment(
                    imageLocation: item.imageLocation,
                    identifier: "complete-\(index)"
                ) {
                    content.attachments = [attachment]
                }
            }

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )

            let request = UNNotificationRequest(
                identifier: "\(notificationPrefix)\(index)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try? await notificationCenter.add(request)
        }
    }

    private func publishStatusNotification(
        for session: WorkoutPlaybackSession,
        presentation: WorkoutPlaybackPresentation?
    ) async {
        guard let presentation else {
            dismissStatusNotification()
            return
        }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = session.isPaused ? pausedNotificationCategory : activeNotificationCategory
        content.title = session.isPaused ? "\(presentation.activeItem.name) paused" : "\(presentation.activeItem.name) in progress"
        content.body = session.isPaused
            ? "Remaining \(formatPlaybackClock(presentation.remainingSeconds))"
            : "Remaining \(formatPlaybackClock(presentation.remainingSeconds))"

        if let attachment = await notificationAttachment(
            imageLocation: presentation.activeItem.imageLocation,
            identifier: "status"
        ) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: statusNotificationIdentifier,
            content: content,
            trigger: nil
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [statusNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [statusNotificationIdentifier])
        try? await notificationCenter.add(request)
    }

    private func updateLiveActivity(presentation: WorkoutPlaybackPresentation?) async {
        guard #available(iOS 16.2, *) else { return }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let presentation {
            let contentState = SemaphoreLiveActivityAttributes.ContentState(
                workoutName: presentation.activeItem.name,
                startDate: presentation.timerRange.lowerBound,
                endDate: presentation.timerRange.upperBound,
                remainingSeconds: presentation.remainingSeconds,
                isPlayingAll: presentation.isPlayingAll,
                remainingQueueCount: presentation.remainingQueueCount,
                isPaused: presentation.isPaused,
                imageData: await liveActivityImageData(from: presentation.activeItem.imageLocation)
            )
            let activityID = defaults.string(forKey: liveActivityIDKey)

            if let existingActivityID = await updateLiveActivityIfPresent(
                activityID: activityID,
                contentState: contentState,
                staleDate: presentation.timerRange.upperBound
            ) {
                defaults.set(existingActivityID, forKey: liveActivityIDKey)
            } else {
                if let newActivityID = await requestLiveActivity(
                    contentState: contentState,
                    staleDate: presentation.timerRange.upperBound
                )
                {
                    defaults.set(newActivityID, forKey: liveActivityIDKey)
                }
            }
        } else {
            await endLiveActivity()
        }
    }

    private func endLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }

        let activityID = defaults.string(forKey: liveActivityIDKey)
        if await endLiveActivityIfPresent(activityID: activityID) {
            defaults.removeObject(forKey: liveActivityIDKey)
        }
    }

    private func notificationAttachment(
        imageLocation: String?,
        identifier: String
    ) async -> UNNotificationAttachment? {
        guard let imageLocation,
              let data = await loadPlaybackMediaData(from: imageLocation),
              let temporaryURL = try? writeTemporaryMedia(
                data: data,
                identifier: identifier,
                preferredFileExtension: playbackFileExtension(for: data)
              )
        else {
            return nil
        }

        return try? UNNotificationAttachment(identifier: identifier, url: temporaryURL)
    }

    private func liveActivityImageData(from imageLocation: String?) async -> Data? {
        guard let imageLocation,
              let data = await loadPlaybackMediaData(from: imageLocation)
        else {
            return nil
        }

        guard let image = previewImage(from: data) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 72, height: 72))
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: 72, height: 72)))
        }

        return rendered.jpegData(compressionQuality: 0.45)
    }
}

@available(iOS 16.2, *)
@MainActor
private func findLiveActivity(
    activityID: String?
) -> Activity<SemaphoreLiveActivityAttributes>? {
    guard let activityID else {
        return Activity<SemaphoreLiveActivityAttributes>.activities.first
    }

    return Activity<SemaphoreLiveActivityAttributes>.activities.first { $0.id == activityID }
        ?? Activity<SemaphoreLiveActivityAttributes>.activities.first
}

@available(iOS 16.2, *)
@MainActor
private func updateLiveActivityIfPresent(
    activityID: String?,
    contentState: SemaphoreLiveActivityAttributes.ContentState,
    staleDate: Date
) async -> String? {
    guard let activity = findLiveActivity(activityID: activityID) else { return nil }

    await activity.update(
        ActivityContent(
            state: contentState,
            staleDate: staleDate
        )
    )
    return activity.id
}

@available(iOS 16.2, *)
@MainActor
private func requestLiveActivity(
    contentState: SemaphoreLiveActivityAttributes.ContentState,
    staleDate: Date
) async -> String? {
    let activity = try? Activity<SemaphoreLiveActivityAttributes>.request(
        attributes: SemaphoreLiveActivityAttributes(routineName: "Semaphore"),
        content: ActivityContent(
            state: contentState,
            staleDate: staleDate
        ),
        pushType: nil
    )

    return activity?.id
}

@available(iOS 16.2, *)
@MainActor
private func endLiveActivityIfPresent(activityID: String?) async -> Bool {
    guard let activity = findLiveActivity(activityID: activityID) else { return false }
    await activity.end(nil, dismissalPolicy: .immediate)
    return true
}

private func loadPlaybackMediaData(from imageLocation: String) async -> Data? {
    if let url = URL(string: imageLocation), url.isFileURL {
        return try? Data(contentsOf: url)
    }

    if let url = URL(string: imageLocation) {
        return try? await URLSession.shared.data(from: url).0
    }

    return nil
}

private func previewImage(from data: Data) -> UIImage? {
    if data.starts(with: [0x47, 0x49, 0x46]),
       let source = CGImageSourceCreateWithData(data as CFData, nil),
       let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
        return UIImage(cgImage: cgImage)
    }

    return UIImage(data: data)
}

private func playbackFileExtension(for data: Data) -> String {
    if data.starts(with: [0x47, 0x49, 0x46]) {
        return "gif"
    }

    if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        return "png"
    }

    if data.starts(with: [0xFF, 0xD8, 0xFF]) {
        return "jpg"
    }

    return "dat"
}

private func writeTemporaryMedia(
    data: Data,
    identifier: String,
    preferredFileExtension: String
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SemaphoreNotifications",
        isDirectory: true
    )

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    let fileURL = directory.appendingPathComponent("\(identifier).\(preferredFileExtension)")

    try data.write(to: fileURL, options: [.atomic])
    return fileURL
}
