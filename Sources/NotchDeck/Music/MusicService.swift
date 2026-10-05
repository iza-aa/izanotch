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
    /// Raw PNG/JPEG bytes downloaded from Spotify's CDN artwork URL.
    public var artworkData: Data?
    public var lyrics: [LyricLine]

    public init(
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool = false,
        playbackPosition: Double = 0,
        trackDuration: Double = 0,
        artworkData: Data? = nil,
        lyrics: [LyricLine] = []
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.playbackPosition = playbackPosition
        self.trackDuration = trackDuration
        self.artworkData = artworkData
        self.lyrics = lyrics
    }

    /// Convenience: resolve NSImage from raw data.
    public var albumArtImage: NSImage? {
        guard let data = artworkData else { return nil }
        return NSImage(data: data)
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

    /// True when metadata is being fetched.
    @Published public var isLoading: Bool = false

    /// True while lrclib lyrics fetch is in-flight.
    @Published public var isFetchingLyrics: Bool = false

    // URL-based caches so artwork/lyrics are not re-fetched on minor state changes
    private var cachedArtworkURL: String?
    private var cachedArtworkData: Data?
    private var cachedLyricsKey: String?   // "\(title)|\(artist)"
    private var cachedLyrics: [LyricLine] = []

    private var notificationTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?

    public init() {
        // Auto-refresh when Spotify signals a playback state change.
        notificationTask = Task { [weak self] in
            let notifications = DistributedNotificationCenter.default().notifications(
                named: NSNotification.Name("com.spotify.client.PlaybackStateChanged")
            )
            for await _ in notifications {
                guard let self else { return }
                await self.fetchCurrentTrack()
            }
        }
    }

    deinit {
        notificationTask?.cancel()
        artworkTask?.cancel()
        lyricsTask?.cancel()
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        runScript("tell application \"Spotify\" to playpause")
        currentTrack?.isPlaying.toggle()
    }

    public func nextTrack() {
        runScript("tell application \"Spotify\" to next track")
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

    public func fetchCurrentTrack() async {
        isLoading = true
        defer { isLoading = false }

        // Check if Spotify is running
        let isRunning = await Task.detached(priority: .userInitiated) {
            let script = "tell application \"System Events\" to (name of processes) contains \"Spotify\""
            guard let appleScript = NSAppleScript(source: script) else { return false }
            var errDict: NSDictionary?
            return appleScript.executeAndReturnError(&errDict).booleanValue
        }.value

        guard isRunning else {
            self.currentTrack = nil
            self.musicError = "Spotify belum terhubung"
            return
        }

        // Fetch metadata + artwork URL in one AppleScript round-trip
        let fetchScript = """
        tell application "Spotify"
            set t      to name of current track
            set ar     to artist of current track
            set al     to album of current track
            set dur    to duration of current track
            set pos    to player position
            set ps     to (player state as string)
            set artURL to artwork url of current track
            return t & "|||" & ar & "|||" & al & "|||" & dur & "|||" & pos & "|||" & ps & "|||" & artURL
        end tell
        """

        let (raw, errMsg) = await Task.detached(priority: .userInitiated) { () -> (String?, String?) in
            guard let script = NSAppleScript(source: fetchScript) else { return (nil, "AppleScript init failed") }
            var errDict: NSDictionary?
            let desc = script.executeAndReturnError(&errDict)
            if let err = errDict {
                return (nil, err[NSAppleScript.errorMessage] as? String ?? "Unknown error")
            }
            return (desc.stringValue, nil)
        }.value

        if let errMsg {
            self.musicError = errMsg
            self.currentTrack = nil
            return
        }

        guard let raw else {
            self.musicError = "Tidak ada respons dari Spotify"
            self.currentTrack = nil
            return
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 7 else {
            self.musicError = "Format respons tidak valid"
            self.currentTrack = nil
            return
        }

        let title      = parts[0]
        let artist     = parts[1]
        let album      = parts[2]
        let duration   = Double(parts[3].trimmingCharacters(in: .whitespaces)) ?? 0
        let position   = Double(parts[4].trimmingCharacters(in: .whitespaces)) ?? 0
        let isPlaying  = parts[5].trimmingCharacters(in: .whitespaces).lowercased().contains("playing")
        let artworkURL = parts[6].trimmingCharacters(in: .whitespaces)

        // Resolve artwork from cache (avoid flicker)
        let artwork: Data? = (artworkURL == cachedArtworkURL) ? cachedArtworkData : cachedArtworkData

        // Resolve lyrics from cache
        let lyricsKey = "\(title)|\(artist)"
        let resolvedLyrics = (lyricsKey == cachedLyricsKey) ? cachedLyrics : []

        self.currentTrack = MusicTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackPosition: position,
            trackDuration: duration / 1000,
            artworkData: artwork,
            lyrics: resolvedLyrics
        )
        self.musicError = nil

        // Async: download artwork if URL changed
        if !artworkURL.isEmpty, artworkURL != cachedArtworkURL {
            let urlToFetch = artworkURL
            artworkTask?.cancel()
            artworkTask = Task { [weak self] in
                guard let data = await Self.downloadData(from: urlToFetch) else { return }
                guard let self, !Task.isCancelled else { return }
                self.cachedArtworkURL = urlToFetch
                self.cachedArtworkData = data
                self.currentTrack?.artworkData = data
            }
        }

        // Async: fetch lyrics if track identity changed
        if lyricsKey != cachedLyricsKey {
            cachedLyricsKey = lyricsKey
            cachedLyrics = []
            lyricsTask?.cancel()
            lyricsTask = Task { [weak self] in
                guard let self else { return }
                await MainActor.run { self.isFetchingLyrics = true }
                let lines = await Self.fetchLyricsFromLrclib(
                    title: title, artist: artist, album: album, duration: duration / 1000
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isFetchingLyrics = false
                    self.cachedLyrics = lines
                    self.currentTrack?.lyrics = lines
                }
            }
        }
    }

    // MARK: - Album Art download

    private static func downloadData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    // MARK: - Lyrics via lrclib.net (free, no API key)

    private static func fetchLyricsFromLrclib(
        title: String,
        artist: String,
        album: String,
        duration: Double
    ) async -> [LyricLine] {
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            URLQueryItem(name: "track_name",  value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name",  value: album),
            URLQueryItem(name: "duration",    value: String(Int(duration)))
        ]
        guard let url = comps.url else { return [] }

        guard
            let (data, resp) = try? await URLSession.shared.data(from: url),
            (resp as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        // Prefer synced LRC lyrics
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            return parseLRC(synced)
        }

        // Fallback: plain lyrics, assign fake timestamps (3s per line)
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            return plain
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .enumerated()
                .map { LyricLine(id: $0.offset, timeSeconds: Double($0.offset) * 3.0, text: $0.element) }
        }

        return []
    }

    /// Parse LRC format lines: `[mm:ss.xx] text`
    private static func parseLRC(_ raw: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+):(\d+\.\d+)\]\s*(.*)"#) else { return [] }
        var lines: [LyricLine] = []
        raw.components(separatedBy: "\n").enumerated().forEach { idx, line in
            let ns = line as NSString
            guard let m = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return }
            let minutes = Double(ns.substring(with: m.range(at: 1))) ?? 0
            let seconds = Double(ns.substring(with: m.range(at: 2))) ?? 0
            let text    = m.range(at: 3).location != NSNotFound ? ns.substring(with: m.range(at: 3)) : ""
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            lines.append(LyricLine(id: idx, timeSeconds: minutes * 60 + seconds, text: text))
        }
        return lines.sorted { $0.timeSeconds < $1.timeSeconds }
    }

    // MARK: - AppleScript helper

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
