import Foundation
import Combine

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let timeSeconds: Double
    public let text: String

    public init(id: Int, timeSeconds: Double, text: String) {
        self.id = id
        self.timeSeconds = timeSeconds
        self.text = text
    }
}

public struct MusicTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var playbackPosition: Double
    public var trackDuration: Double
    public var lyrics: [LyricLine]

    public init(
        title: String = "No Track Playing",
        artist: String = "Connect Spotify or Music.app",
        album: String = "NotchDeck Audio",
        isPlaying: Bool = false,
        playbackPosition: Double = 0,
        trackDuration: Double = 180,
        lyrics: [LyricLine] = []
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.playbackPosition = playbackPosition
        self.trackDuration = trackDuration
        self.lyrics = lyrics
    }
}

@MainActor
public final class MusicService: ObservableObject {
    public static let shared = MusicService()

    @Published public var currentTrack: MusicTrack = MusicTrack(
        title: "Starboy",
        artist: "The Weeknd, Daft Punk",
        album: "Starboy",
        isPlaying: true,
        playbackPosition: 45,
        trackDuration: 230,
        lyrics: [
            LyricLine(id: 0, timeSeconds: 0, text: "♪ (Intro instrumental) ♪"),
            LyricLine(id: 1, timeSeconds: 15, text: "I'm tryna put you in the worst mood, ah"),
            LyricLine(id: 2, timeSeconds: 22, text: "P1 cleaner than your church shoes, ah"),
            LyricLine(id: 3, timeSeconds: 30, text: "Milli point two just to hurt you, ah"),
            LyricLine(id: 4, timeSeconds: 40, text: "All red Lamb' just to tease you, ah"),
            LyricLine(id: 5, timeSeconds: 48, text: "Look what you've done, I'm a motherfuckin' starboy"),
            LyricLine(id: 6, timeSeconds: 60, text: "Every day a nigga try to test me, ah"),
            LyricLine(id: 7, timeSeconds: 72, text: "Every day a nigga try to end me, ah")
        ]
    )

    public init() {}

    public func togglePlayPause() {
        currentTrack.isPlaying.toggle()
        executeScript("tell application \"Spotify\" to playpause")
    }

    public func nextTrack() {
        executeScript("tell application \"Spotify\" to next track")
    }

    public func previousTrack() {
        executeScript("tell application \"Spotify\" to previous track")
    }

    private func executeScript(_ scriptSource: String) {
        // Safe AppleScript dispatch for desktop media control
        guard let script = NSAppleScript(source: scriptSource) else { return }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
    }
}
