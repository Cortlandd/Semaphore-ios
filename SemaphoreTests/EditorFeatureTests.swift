import ComposableArchitecture
import XCTest
@testable import Semaphore

@MainActor
final class EditorFeatureTests: XCTestCase {
    func testSaveTappedRequiresValidDraft() async {
        let store = TestStore(initialState: EditorFeature.State()) {
            EditorFeature()
        }

        await store.send(.saveTapped) {
            $0.errorMessage = "Enter a workout name and choose a non-zero duration."
        }
    }

    func testPickingMediaClearsExistingRemoteState() async {
        var initialState = EditorFeature.State()
        initialState.currentImageLocation = "https://example.com/old.gif"
        initialState.remoteImageURL = "https://example.com/old.gif"

        let store = TestStore(initialState: initialState) {
            EditorFeature()
        }

        let data = Data([0x47, 0x49, 0x46, 0x38])
        await store.send(.pickedMedia(data)) {
            $0.selectedMediaData = data
            $0.currentImageLocation = nil
            $0.remoteImageURL = ""
        }
    }

    func testBindingRemoteURLClearsImportedMedia() async {
        var initialState = EditorFeature.State()
        initialState.selectedMediaData = Data([0x01, 0x02])
        initialState.currentImageLocation = "file:///tmp/local.gif"

        let store = TestStore(initialState: initialState) {
            EditorFeature()
        }

        await store.send(.binding(.set(\.remoteImageURL, "https://example.com/new.gif"))) {
            $0.remoteImageURL = "https://example.com/new.gif"
            $0.selectedMediaData = nil
            $0.currentImageLocation = nil
        }
    }
}
