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

    @Test("MusicService starts with no track (nil) — no mock data")
    @MainActor
    func testMusicServiceStartsEmpty() {
        let service = MusicService()
        // After Fix 3: currentTrack must be nil initially — no mock/demo data
        #expect(service.currentTrack == nil)
        #expect(service.isLoading == false)
    }

    @Test("MusicService play/pause toggle updates in-memory track state")
    @MainActor
    func testMusicServiceToggleWithTrack() {
        let service = MusicService()
        // Manually set a track (simulating what fetchCurrentTrack() would do)
        service.currentTrack = MusicTrack(
            title: "Test Track",
            artist: "Test Artist",
            album: "Test Album",
            isPlaying: false
        )
        let initialPlaying = service.currentTrack?.isPlaying ?? false
        service.togglePlayPause()
        // Local state should toggle immediately (even if AppleScript may fail in test env)
        #expect(service.currentTrack?.isPlaying == !initialPlaying)
    }

    @Test("LyricLine active state is determined by playback position")
    func testActiveLyricByPosition() {
        let lines = [
            LyricLine(id: 0, timeSeconds: 0, text: "Intro"),
            LyricLine(id: 1, timeSeconds: 15, text: "Verse 1"),
            LyricLine(id: 2, timeSeconds: 30, text: "Chorus")
        ]
        let track = MusicTrack(
            title: "T", artist: "A", album: "B",
            playbackPosition: 20,
            lyrics: lines
        )
        // Lines with timeSeconds <= playbackPosition (20) are "active"
        let activeLines = track.lyrics.filter { $0.timeSeconds <= track.playbackPosition }
        #expect(activeLines.count == 2)  // lines at 0s and 15s
        #expect(activeLines.last?.text == "Verse 1")
    }
}
