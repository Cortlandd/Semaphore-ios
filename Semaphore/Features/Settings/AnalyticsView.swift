import SwiftUI

struct AnalyticsView: View {
    let workouts: [Workout]

    private var summary: AnalyticsSummary {
        AnalyticsSummary(workouts: workouts)
    }

    var body: some View {
        GridBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard

                    if workouts.isEmpty {
                        VStack(spacing: 12) {
                            Text("No workouts yet")
                                .font(.title3.weight(.bold))
                            Text("Add a workout to start tracking your streaks and completion counts.")
                                .foregroundStyle(SemaphorePalette.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        Text("Individual Workouts")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(SemaphorePalette.accent)

                        ForEach(workouts) { workout in
                            workoutCard(workout)
                        }
                    }
                }
                .padding(24)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SUMMARY")
                .font(.caption.weight(.bold))
                .foregroundStyle(SemaphorePalette.primary)

            Text("Weekly Progress")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(SemaphorePalette.accent)

            HStack(spacing: 12) {
                metric("WORKOUTS", "\(summary.totalCompletedWorkouts)")
                metric("HOURS", String(format: "%.1f", summary.totalHours))
                metric("STREAK", "\(summary.currentStreak)d")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(spacing: 0) {
            WorkoutMediaView(
                imageLocation: workout.imageLocation,
                selectedData: nil,
                height: 150,
                cornerRadius: 28,
                overlayIcon: workout.durationSeconds >= 60 ? "bolt.fill" : "figure.cooldown"
            )

            VStack(alignment: .leading, spacing: 16) {
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SemaphorePalette.accent)

                HStack(spacing: 16) {
                    metric("TIMES COMPLETED", "\(workout.completedCount) sessions")
                    metric("TOTAL TIME", formatTrackedDuration(workout.totalTimeSpentSeconds))
                }

                metric("LAST PERFORMED", formatLastPerformed(workout.lastPerformedAt))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(SemaphorePalette.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(SemaphorePalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SemaphorePalette.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
