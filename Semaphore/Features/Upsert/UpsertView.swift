//
//  UpsertView.swift
//  Semaphore
//
//  Created by Cortland on 4/9/26.
//  Copyright © 2026 Cortland Walker. All rights reserved.
//

import SwiftUI
import ComposableArchitecture
import PhotosUI

public struct UpsertView: View {
    @Perception.Bindable var store: StoreOf<UpsertFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var photosPickerItem: PhotosPickerItem?

    public init(store: StoreOf<UpsertFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            GridBackground(backgroundColor: SemaphorePalette.background) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            mediaHeader

                            VStack(spacing: 24) {
                                TextField("Workout Name", text: $store.name)
                                    .textInputAutocapitalization(.words)
                                    .font(.title3.weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 22)
                                    .frame(height: 64)
                                    .background(Color.white, in: Capsule())
                                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Duration")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(SemaphorePalette.accent)

                                    TimePickerCard(store: store)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Remote GIF / Image URL")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(SemaphorePalette.secondaryText)

                                    TextField(
                                        "https://example.com/workout.gif",
                                        text: $store.remoteImageURL
                                    )
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }

                                if store.currentImageLocation != nil ||
                                    store.selectedMediaData != nil ||
                                    !store.remoteImageURL.isEmpty {
                                    Button("Remove Media") {
                                        store.send(.removeMediaTapped)
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(SemaphorePalette.danger)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, -20)
                            .padding(.bottom, 120)
                        }
                    }

                    Button {
                        store.send(.saveTapped)
                    } label: {
                        Text(store.isEdit ? "Save Changes" : "Create Workout")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                store.isValid ? SemaphorePalette.primary : Color.gray,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isValid)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .alert(
                "Unable to Save",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            store.send(.dismissError)
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    store.send(.dismissError)
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .onChange(of: photosPickerItem) { newValue in
                guard let newValue else { return }

                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        store.send(.pickedMedia(data))
                    }
                }
            }
            .onChange(of: store.workoutID) { _ in
                if store.workoutID == nil && !store.isEdit {
                    return
                }
            }
        }
    }

    private var mediaHeader: some View {
        let previewImageLocation = store.currentImageLocation ?? (
            isRemoteURL(store.remoteImageURL) ? store.remoteImageURL : nil
        )
        let previewData = store.selectedMediaData
        let isEditing = store.isEdit

        return ZStack(alignment: .top) {
            VStack(spacing: 18) {
                Spacer(minLength: 80)

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    WorkoutMediaView(
                        imageLocation: previewImageLocation,
                        selectedData: previewData,
                        height: 170,
                        cornerRadius: 30,
                        overlayIcon: "photo.badge.plus"
                    )
                    .frame(width: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .shadow(color: SemaphorePalette.primary.opacity(0.18), radius: 18, y: 10)
                }
                .buttonStyle(.plain)

                VStack(spacing: 6) {
                    Text(isEditing ? "Edit Workout" : "New Workout")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(SemaphorePalette.accent)

                    Text("Tap the cover to choose local media")
                        .font(.subheadline)
                        .foregroundStyle(SemaphorePalette.secondaryText)
                }

                Spacer(minLength: 42)
            }
            .padding(.horizontal, 24)
            .frame(height: 360)

            HStack {
                CapsuleIconButton(systemImage: "xmark") {
                    store.send(.cancelTapped)
                    dismiss()
                }

                Spacer()

                Text(isEditing ? "Editing" : "Creating")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
}

private struct TimePickerCard: View {
    @Perception.Bindable var store: StoreOf<UpsertFeature>

    var body: some View {
        HStack(spacing: 12) {
            TimeWheel(
                title: "Hours",
                range: 0..<24,
                value: $store.hours
            )
            TimeWheel(
                title: "Minutes",
                range: 0..<60,
                value: $store.minutes
            )
            TimeWheel(
                title: "Seconds",
                range: 0..<60,
                value: $store.seconds
            )
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

private struct TimeWheel: View {
    var title: String
    var range: Range<Int>
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(SemaphorePalette.secondaryText)

            Picker(title, selection: $value) {
                ForEach(Array(range), id: \.self) { item in
                    Text(String(format: "%02d", item))
                        .tag(item)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .clipped()
        }
    }
}
