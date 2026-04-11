//
//  WorkoutListView.swift
//  Semaphore
//
//  Created by Cortland on 4/9/26.
//  Copyright © 2026 Cortland Walker. All rights reserved.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

public struct WorkoutListView: View {
    let store: StoreOf<WorkoutListFeature>

    @State private var draggedWorkoutID: String?

    public init(store: StoreOf<WorkoutListFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            GridBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header

                            if store.workouts.isEmpty {
                                emptyState
                            } else {
                                statCards

                                Text("Your Routine")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(SemaphorePalette.accent)

                                LazyVStack(spacing: 16) {
                                    ForEach(store.workouts) { workout in
                                        WorkoutRow(
                                            workout: workout,
                                            isActive: store.activeWorkoutId == workout.id,
                                            isPaused: store.isPlaybackPaused,
                                            activeTimer: store.activeWorkoutId == workout.id
                                                ? store.activeWorkoutTimer
                                                : nil,
                                            onOpen: { store.send(.workoutTapped(workout.id)) },
                                            onPlay: { store.send(.singlePlayTapped(workout.id)) },
                                            onDelete: { store.send(.deleteTapped(workout.id)) }
                                        )
                                        .onDrag {
                                            draggedWorkoutID = workout.id
                                            return NSItemProvider(object: NSString(string: workout.id))
                                        }
                                        .onDrop(
                                            of: [UTType.plainText],
                                            delegate: WorkoutDropDelegate(
                                                item: workout,
                                                workouts: store.workouts,
                                                draggedWorkoutID: $draggedWorkoutID,
                                                onMove: { from, to in
                                                    store.send(.moveWorkout(from: from, to: to))
                                                }
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 140)
                    }

                    bottomBar
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Semaphore")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black)

                if !store.workouts.isEmpty {
                    Text("Ready to work out?")
                        .font(.subheadline)
                        .foregroundStyle(SemaphorePalette.secondaryText)
                }
            }

            Spacer()

            CapsuleIconButton(systemImage: "plus") {
                store.send(.addTapped)
            }
        }
    }

    private var statCards: some View {
        HStack(spacing: 16) {
            StatCard(background: SemaphorePalette.primary) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOTAL TIME")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.8))

                    Text(
                        formatWorkoutDuration(
                            store.workouts.reduce(0) { $0 + $1.durationSeconds }
                        )
                    )
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                }
            }

            StatCard(background: SemaphorePalette.card) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WORKOUTS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SemaphorePalette.secondaryText)

                    Text("\(store.workouts.count)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(SemaphorePalette.accent)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    VStack(spacing: 14) {
                        Image(systemName: "bolt.heart")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(SemaphorePalette.primary)

                        Text("Build your first routine")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SemaphorePalette.accent)

                        Text("Add workout timers, drag them into order, and hit play when you're ready.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SemaphorePalette.secondaryText)
                            .padding(.horizontal, 20)
                    }
                    .padding(30)
                )
                .frame(height: 260)

            Spacer(minLength: 40)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            CapsuleIconButton(systemImage: "gearshape.fill") {
                store.send(.settingsTapped)
            }

            if store.playbackSession != nil {
                CapsuleIconButton(systemImage: "stop.fill") {
                    store.send(.stopTapped)
                }

                Button {
                    store.send(store.isPlaybackPaused ? .resumeTapped : .pauseTapped)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: store.isPlaybackPaused ? "play.fill" : "pause.fill")
                        Text(store.isPlaybackPaused ? "Resume" : "Pause")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(SemaphorePalette.primary, in: Capsule())
                    .shadow(color: SemaphorePalette.primary.opacity(0.28), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if store.workouts.isEmpty {
                        store.send(.addTapped)
                    } else {
                        store.send(.playAllTapped)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text(store.workouts.isEmpty ? "Add Workout" : "Play All")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(SemaphorePalette.primary, in: Capsule())
                    .shadow(color: SemaphorePalette.primary.opacity(0.28), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 26)
    }
}

private struct WorkoutRow: View {
    var workout: Workout
    var isActive: Bool
    var isPaused: Bool
    var activeTimer: String?
    var onOpen: () -> Void
    var onPlay: () -> Void
    var onDelete: () -> Void

    @Namespace private var heroNamespace

    private var hasHeroMedia: Bool {
        guard let imageLocation = workout.imageLocation else { return false }
        return !imageLocation.isEmpty
    }

    private var showsExpandedCard: Bool {
        isActive && hasHeroMedia
    }

    var body: some View {
        ZStack {
            if showsExpandedCard {
                expandedCard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else {
                collapsedCard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: showsExpandedCard ? 380 : 100)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    isActive ? SemaphorePalette.primary : .clear,
                    lineWidth: isActive ? 2 : 0
                )
        )
        .shadow(
            color: showsExpandedCard ? SemaphorePalette.primary.opacity(0.14) : .black.opacity(0.05),
            radius: showsExpandedCard ? 18 : 8,
            y: showsExpandedCard ? 12 : 4
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Edit", action: onOpen)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.84), value: showsExpandedCard)
        .animation(.easeInOut(duration: 0.24), value: isActive)
    }

    private var collapsedCard: some View {
        Group {
            if isActive {
                activeCompactCard
            } else {
                idleCompactCard
            }
        }
    }

    private var idleCompactCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.gray.opacity(0.45))

            WorkoutThumb(
                imageLocation: workout.imageLocation,
                size: 64,
                namespace: heroNamespace,
                heroID: heroID("media")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(workout.name.ifEmpty("Untitled"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: heroID("title"), in: heroNamespace)

                Text(formatCompactDuration(workout.durationSeconds))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.941, green: 0.941, blue: 0.961), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .matchedGeometryEffect(id: heroID("duration"), in: heroNamespace)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            playButton(isStop: false)
                .matchedGeometryEffect(id: heroID("action"), in: heroNamespace)
        }
        .padding(.horizontal, 16)
    }

    private var activeCompactCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name.ifEmpty("Untitled"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SemaphorePalette.primary)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: heroID("title"), in: heroNamespace)

                Text("Current Interval")
                    .font(.caption)
                    .foregroundStyle(Color.gray)

                if isPaused {
                    Text("Paused")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SemaphorePalette.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            activeTimerPill
                .matchedGeometryEffect(id: heroID("duration"), in: heroNamespace)

            playButton(isStop: true)
                .matchedGeometryEffect(id: heroID("action"), in: heroNamespace)
        }
        .padding(.horizontal, 20)
    }

    private var expandedCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name.ifEmpty("Untitled"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(SemaphorePalette.primary)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: heroID("title"), in: heroNamespace)

                    Text("Current Interval")
                        .font(.caption)
                        .foregroundStyle(Color.gray)

                    if isPaused {
                        Text("Paused")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SemaphorePalette.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                activeTimerPill
                    .matchedGeometryEffect(id: heroID("duration"), in: heroNamespace)

                playButton(isStop: true)
                    .matchedGeometryEffect(id: heroID("action"), in: heroNamespace)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ZStack(alignment: .topLeading) {
                WorkoutHeroMedia(
                    imageLocation: workout.imageLocation,
                    namespace: heroNamespace,
                    heroID: heroID("media")
                )

                Text("ACTIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(alignment: .leading) {
                        Circle()
                            .fill(Color(red: 0, green: 0.902, blue: 0.463))
                            .frame(width: 6, height: 6)
                            .offset(x: -6)
                    }
                    .padding(16)
            }
        }
    }

    private var activeTimerPill: some View {
        HStack(spacing: 4) {
                Text(activeTimer ?? "00:00")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SemaphorePalette.primary)

            Text("/ \(formatPlaybackClock(max(workout.durationSeconds, 1)))")
                .font(.caption)
                .foregroundStyle(Color.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.922, green: 0.914, blue: 0.973), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func playButton(isStop: Bool) -> some View {
        Button(action: onPlay) {
            Image(systemName: isStop ? (isPaused ? "play.fill" : "pause.fill") : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isStop ? SemaphorePalette.primary : .white)
                .frame(width: isStop ? 40 : 48, height: isStop ? 40 : 48)
                .background(
                    isStop
                        ? Color(red: 0.941, green: 0.941, blue: 0.961)
                        : SemaphorePalette.primary,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }

    private func heroID(_ suffix: String) -> String {
        "\(workout.id)-\(suffix)"
    }
}

private struct WorkoutThumb: View {
    var imageLocation: String?
    var size: CGFloat
    var namespace: Namespace.ID
    var heroID: String

    @State private var loadedData: Data?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.941, green: 0.941, blue: 0.961))

            if let data = loadedData {
                AnimatedImage(data: data)
                    .clipShape(Circle())
            } else {
                Text("GIF")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.gray.opacity(0.65))
            }
        }
        .frame(width: size, height: size)
        .matchedGeometryEffect(id: heroID, in: namespace)
        .task(id: imageLocation) {
            loadedData = await loadMediaData(from: imageLocation)
        }
    }
}

private struct WorkoutHeroMedia: View {
    var imageLocation: String?
    var namespace: Namespace.ID
    var heroID: String

    var body: some View {
        WorkoutMediaView(
            imageLocation: imageLocation,
            selectedData: nil,
            height: 288,
            cornerRadius: 0,
            overlayIcon: "bolt.fill"
        )
        .matchedGeometryEffect(id: heroID, in: namespace)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }
}

private func formatCompactDuration(_ totalSeconds: Int) -> String {
    formatPlaybackClock(max(totalSeconds, 1))
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        self.isEmpty ? fallback : self
    }
}

private struct WorkoutDropDelegate: DropDelegate {
    let item: Workout
    let workouts: [Workout]
    @Binding var draggedWorkoutID: String?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard
            let draggedWorkoutID,
            draggedWorkoutID != item.id,
            let fromIndex = workouts.firstIndex(where: { $0.id == draggedWorkoutID }),
            let toIndex = workouts.firstIndex(where: { $0.id == item.id })
        else {
            return
        }

        onMove(fromIndex, toIndex)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedWorkoutID = nil
        return true
    }
}
