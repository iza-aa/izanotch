import Testing
import Foundation
@testable import NotchDeck

@Suite("Music Service & Lyrics Tests")
struct MusicServiceTests {
    @Test("LyricLine and MusicTrack data modeling")
    func testMusicTrackModel() {
        let lines = [
            LyricLine(id: 0, timeSeconds: 0, text: "Intro"),
            LyricLine(id: 1, timeSeconds: 15, text: "First verse line")
        ]
        let track = MusicTrack(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            isPlaying: true,
            playbackPosition: 30,
            trackDuration: 200,
            lyrics: lines
        )

        #expect(track.title == "Blinding Lights")
        #expect(track.artist == "The Weeknd")
        #expect(track.isPlaying == true)
        #expect(track.lyrics.count == 2)
        #expect(track.lyrics.first?.text == "Intro")
    }

    @Test("MusicService play/pause toggle")
    @MainActor
    func testMusicServiceToggle() {
        let service = MusicService()
        let initialPlaying = service.currentTrack.isPlaying
        service.togglePlayPause()
        #expect(service.currentTrack.isPlaying == !initialPlaying)
    }
}
