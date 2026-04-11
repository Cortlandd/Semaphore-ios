import ComposableArchitecture
import SwiftUI

public struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            GridBackground {
                ScrollView {
                    VStack(spacing: 0) {
                        settingsHeader

                        VStack(alignment: .leading, spacing: 24) {
                            sectionHeader("GENERAL")
                            infoCard {
                                NavigationLink {
                                    AnalyticsView(workouts: store.workouts)
                                } label: {
                                    SettingsRow(
                                        icon: "chart.bar.fill",
                                        tint: SemaphorePalette.primary,
                                        title: "Analytics",
                                        subtitle: "View your workout stats"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.horizontal, 20)

                                Link(destination: feedbackMailURL()) {
                                    SettingsRow(
                                        icon: "envelope.fill",
                                        tint: SemaphorePalette.primary,
                                        title: "Send Feedback",
                                        subtitle: "Report bugs or request features"
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            sectionHeader("SUPPORT")
                            supportCard

                            sectionHeader("ABOUT")
                            infoCard {
                                NavigationLink {
                                    MarkdownDocumentView(document: .faq)
                                } label: {
                                    SettingsRow(
                                        icon: "questionmark.circle.fill",
                                        tint: SemaphorePalette.primary,
                                        title: "FAQ",
                                        subtitle: "Questions and answers"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.horizontal, 20)

                                Button {
                                    store.send(.rateTapped)
                                } label: {
                                    SettingsRow(
                                        icon: "star.fill",
                                        tint: .yellow,
                                        title: "Rate App",
                                        subtitle: "Review Semaphore on the App Store"
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Version \(store.version)")
                                .font(.caption)
                                .foregroundStyle(SemaphorePalette.secondaryText.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 30)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, -24)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                CapsuleIconButton(systemImage: "chevron.left") {
                    dismiss()
                }
                Spacer()
            }

            Spacer()

            Text("Settings")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(SemaphorePalette.accent)

            Spacer(minLength: 36)
        }
        .padding(24)
        .frame(height: 250)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remove banner ads")
                .font(.title3.weight(.bold))
                .foregroundStyle(SemaphorePalette.accent)

            Text("The Android app supports one-time ad removal. The iOS billing flow still needs to be connected.")
                .font(.body)
                .foregroundStyle(SemaphorePalette.secondaryText)

            Button("Remove Ads") {
                store.send(.removeAdsTapped)
            }
            .buttonStyle(.borderedProminent)
            .tint(SemaphorePalette.primary)

            Button("Restore Purchase") {
                store.send(.restoreTapped)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(SemaphorePalette.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(SemaphorePalette.secondaryText)
            .padding(.leading, 12)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

private struct SettingsRow: View {
    var icon: String
    var tint: Color
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(SemaphorePalette.accent)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(SemaphorePalette.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(SemaphorePalette.secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
