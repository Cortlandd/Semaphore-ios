import SwiftUI
import UIKit
@preconcurrency import UserNotifications

final class SemaphoreApplicationDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            await WorkoutPlaybackCoordinator.shared.configureNotifications()
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
            await WorkoutPlaybackCoordinator.shared.publishStatusNotificationIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task {
            await WorkoutPlaybackCoordinator.shared.dismissStatusNotification()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await WorkoutPlaybackCoordinator.shared.handleNotificationResponse(response)
            completionHandler()
        }
    }
}

@main
struct SemaphoreApp: App {
    @UIApplicationDelegateAdaptor(SemaphoreApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        WindowGroup {
            SemaphoreRootView()
        }
    }
}
