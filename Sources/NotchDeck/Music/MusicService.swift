import Foundation
import AppKit
import Combine

// MARK: - Models

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
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool = false,
        playbackPosition: Double = 0,
        trackDuration: Double = 0,
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

// MARK: - MusicService

@MainActor
public final class MusicService: ObservableObject {
    public static let shared = MusicService()

    /// `nil` means no music app is running or no track is loaded.
    @Published public var currentTrack: MusicTrack? = nil

    /// Non-nil when a Spotify / AppleScript operation failed.
    @Published public var musicError: String? = nil

    /// True when we are actively polling (Spotify is running but track fetch in-flight).
    @Published public var isLoading: Bool = false

    public init() {}

    // MARK: - Playback Controls

    public func togglePlayPause() {
        runScript("tell application \"Spotify\" to playpause")
        currentTrack?.isPlaying.toggle()
    }

    public func nextTrack() {
        runScript("tell application \"Spotify\" to next track")
        // Re-fetch after a short delay to pick up the new track
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await fetchCurrentTrack()
        }
    }

    public func previousTrack() {
        runScript("tell application \"Spotify\" to previous track")
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await fetchCurrentTrack()
        }
    }

    // MARK: - Track Fetching

    /// Fetches the currently playing track from Spotify via AppleScript.
    /// Sets `musicError` if Spotify is not running or the call fails.
    public func fetchCurrentTrack() async {
        isLoading = true
        defer { isLoading = false }

        // First check if Spotify is running
        let isRunning = await Task.detached(priority: .userInitiated) {
            let script = "tell application \"System Events\" to (name of processes) contains \"Spotify\""
            guard let appleScript = NSAppleScript(source: script) else { return false }
            var errDict: NSDictionary?
            let result = appleScript.executeAndReturnError(&errDict)
            return result.booleanValue
        }.value

        guard isRunning else {
            self.currentTrack = nil
            self.musicError = "Spotify belum terhubung"
            return
        }

        // Fetch track metadata
        let fetchScript = """
        tell application "Spotify"
            set t to name of current track
            set ar to artist of current track
            set al to album of current track
            set dur to duration of current track
            set pos to player position
            set ps to (player state as string)
            return t & "|||" & ar & "|||" & al & "|||" & dur & "|||" & pos & "|||" & ps
        end tell
        """

        let result = await Task.detached(priority: .userInitiated) { () -> (String?, String?) in
            guard let appleScript = NSAppleScript(source: fetchScript) else {
                return (nil, "AppleScript init failed")
            }
            var errDict: NSDictionary?
            let desc = appleScript.executeAndReturnError(&errDict)
            if let err = errDict {
                let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                return (nil, msg)
            }
            return (desc.stringValue, nil)
        }.value

        if let errMsg = result.1 {
            self.musicError = errMsg
            self.currentTrack = nil
            return
        }

        guard let raw = result.0 else {
            self.musicError = "Tidak ada respons dari Spotify"
            self.currentTrack = nil
            return
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else {
            self.musicError = "Format respons Spotify tidak valid"
            self.currentTrack = nil
            return
        }

        let title     = parts[0]
        let artist    = parts[1]
        let album     = parts[2]
        let duration  = Double(parts[3].trimmingCharacters(in: .whitespaces)) ?? 0
        let position  = Double(parts[4].trimmingCharacters(in: .whitespaces)) ?? 0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespaces).lowercased().contains("playing")

        self.currentTrack = MusicTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackPosition: position,
            trackDuration: duration / 1000,  // Spotify returns ms
            lyrics: []  // Lyrics API integration can be added later
        )
        self.musicError = nil
    }

    // MARK: - Private

    @discardableResult
    private func runScript(_ scriptSource: String) -> Bool {
        guard let script = NSAppleScript(source: scriptSource) else {
            self.musicError = "Gagal membuat AppleScript"
            return false
        }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
        if let err = errorDict {
            self.musicError = err[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            return false
        }
        self.musicError = nil
        return true
    }
}
