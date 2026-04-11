# Semaphore iOS

Semaphore is an iOS workout timer app built with SwiftUI and the Composable Architecture. You can create a list of workout timers, attach an optional GIF or image to each one, and run either a single timer or the full routine in sequence.

## Project structure

- `Semaphore/Core` contains app entry, models, persistence, and playback services.
- `Semaphore/Features` contains the main product features like workouts, editor, and settings.
- `Semaphore/Shared` contains shared UI building blocks and theme code.
- `Semaphore/ExtraResources` contains app-owned markdown content such as the FAQ.
- `SemaphoreWidgets` contains the Live Activity widget used for the Lock Screen and Dynamic Island timer UI.

## Requirements

- Xcode 17+
- iOS 16.2+

## Running the app

1. Open `/Users/cortland/development/ios/Semaphore-ios/Semaphore.xcodeproj`.
2. Select the `Semaphore` scheme.
3. Build and run on an iPhone simulator or device.

The project uses Swift Package Manager for dependencies. There is no CocoaPods setup anymore.

## Updating the app version

Semaphore uses the standard Xcode version fields:

- `MARKETING_VERSION`: the App Store version users see, for example `1.4.0`
- `CURRENT_PROJECT_VERSION`: the internal build number, for example `42`

Both values live in `/Users/cortland/development/ios/Semaphore-ios/Semaphore.xcodeproj/project.pbxproj` and are read by the app at runtime. Settings displays the version as `MARKETING_VERSION (CURRENT_PROJECT_VERSION)`.

Recommended release flow:

1. Choose the next App Store version and build number.
2. Update `MARKETING_VERSION` for the `Semaphore` target.
3. Increment `CURRENT_PROJECT_VERSION` for the `Semaphore` target.
4. Keep the widget target on the same version/build so the extension and app stay aligned.
5. Build the app and verify the Settings screen shows the expected value.

## GitHub release flow

1. Commit the version bump and any release-ready changes.
2. Push the release branch.
3. Merge to your main branch when the app is ready.
4. Create a Git tag that matches the marketing version, such as `ios-v1.4.0`.
5. Publish a GitHub release from that tag with the release notes for the shipped changes.

## App Store release flow

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
2. Archive the app in Xcode.
3. Upload the archive to App Store Connect.
4. In App Store Connect, create or select the matching app version.
5. Attach the uploaded build whose build number matches `CURRENT_PROJECT_VERSION`.
6. Add release notes, screenshots, and metadata updates if needed.
7. Submit the build for review.

For a new App Store version, change `MARKETING_VERSION`. For another upload to the same App Store version, leave `MARKETING_VERSION` alone and increment only `CURRENT_PROJECT_VERSION`.

## Background timer behavior

- Playback is based on a persisted wall-clock schedule rather than an in-memory countdown.
- Local notifications fire when a timer finishes and when the next timer begins.
- If a workout has an attached image or GIF, Semaphore adds it to the notification when possible.
- Live Activities show the active timer outside the app while playback is in progress.

Animated GIFs are represented as a still preview image in system surfaces that do not support animation.
