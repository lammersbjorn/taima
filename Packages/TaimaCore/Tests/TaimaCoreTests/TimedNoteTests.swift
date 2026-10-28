import Foundation
import Testing
@testable import TaimaCore

@Suite struct TimedNoteTests {
    @Test func notePhotosAreStoredButNotInTheGallery() {
        var bag = Bag(name: "A", photoName: "front.heic")
        bag.noteLog = [TimedNote(text: "Calm", photoName: "note.heic"), TimedNote(text: "No photo")]
        #expect(bag.photoNames == ["front.heic"])
        #expect(bag.storedPhotoNames == ["front.heic", "note.heic"])
    }

    @Test func editsKeepNotesAddedMeanwhile() {
        let original = Bag(name: "A")
        var stored = original
        stored.noteLog = [TimedNote(text: "Added from the Live Activity")]
        var edited = original
        edited.name = "A edited"
        let merged = Bag.merge(edited: edited, original: original, stored: stored)
        #expect(merged.noteLog.count == 1 && merged.name == "A edited")
    }

    @Test func rescansKeepNotes() {
        var previous = Bag(name: "A")
        previous.noteLog = [TimedNote(text: "x")]
        #expect(Bag(name: "B").keepingPersonalFields(of: previous).noteLog.count == 1)
    }
}
