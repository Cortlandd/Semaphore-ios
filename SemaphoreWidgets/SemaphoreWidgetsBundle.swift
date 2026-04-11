@preconcurrency import ActivityKit
import Foundation
import SwiftUI
import UIKit
import WidgetKit

@main
struct SemaphoreWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            SemaphoreLiveActivityWidget()
        }
    }
}

@available(iOS 16.2, *)
struct SemaphoreLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SemaphoreLiveActivityAttributes.self) { context in
            SemaphoreLiveActivityView(state: context.state)
                .activityBackgroundTint(Color(red: 0.9725, green: 0.9725, blue: 0.9804))
                .activitySystemActionForegroundColor(Color(red: 0.1765, green: 0.1922, blue: 0.2588))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    imageView(data: context.state.imageData)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.workoutName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(statusString(for: context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownView(for: context.state, font: .title3.monospacedDigit().weight(.bold))
                }
            } compactLeading: {
                imageView(data: context.state.imageData)
            } compactTrailing: {
                countdownView(for: context.state, font: .caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func imageView(data: Data?) -> some View {
        if let data,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Image(systemName: "timer")
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
        }
    }

    @ViewBuilder
    private func countdownView(
        for state: SemaphoreLiveActivityAttributes.ContentState,
        font: Font
    ) -> some View {
        if state.isPaused {
            Text(formatPlaybackClock(state.remainingSeconds))
                .font(font)
        } else {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .font(font)
        }
    }

    private func statusString(for state: SemaphoreLiveActivityAttributes.ContentState) -> String {
        if state.isPaused {
            return "Paused"
        }

        if state.isPlayingAll {
            return "\(max(state.remainingQueueCount, 0)) left after this"
        }

        return "Single workout"
    }
}

@available(iOS 16.2, *)
private struct SemaphoreLiveActivityView: View {
    let state: SemaphoreLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            if let data = state.imageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(state.workoutName)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                if state.isPaused {
                    Text(formatPlaybackClock(state.remainingSeconds))
                        .font(.system(.title2, design: .rounded).monospacedDigit().weight(.heavy))
                } else {
                    Text(
                        timerInterval: state.startDate...state.endDate,
                        countsDown: true
                    )
                    .font(.system(.title2, design: .rounded).monospacedDigit().weight(.heavy))
                }

                Text(state.isPaused ? "Paused" : (state.isPlayingAll ? "Routine in progress" : "Workout in progress"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private func formatPlaybackClock(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}
