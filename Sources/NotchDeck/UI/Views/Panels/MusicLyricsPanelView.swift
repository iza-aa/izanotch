import SwiftUI

public struct MusicLyricsPanelView: View {
    @ObservedObject public var musicService: MusicService

    public init(musicService: MusicService = .shared) {
        self.musicService = musicService
    }

    public var body: some View {
        VStack(spacing: 8) {
            if musicService.isLoading {
                loadingView
            } else if let track = musicService.currentTrack {
                trackView(track)
            } else {
                emptyView
            }
        }
        .onAppear {
            Task { await musicService.fetchCurrentTrack() }
        }
    }

    // MARK: - Sub-views

    /// State when no track or Spotify is not running.
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 12)

            Image(systemName: "music.slash")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.25))

            Text(musicService.musicError ?? "Spotify belum terhubung")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: {
                Task { await musicService.fetchCurrentTrack() }
            }) {
                Label("Coba Lagi", systemImage: "arrow.clockwise")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 20)
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white.opacity(0.5))
            Text("Menghubungkan ke Spotify...")
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.4))
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func trackView(_ track: MusicTrack) -> some View {
        // 1. Now Playing Header & Playback Controls
        HStack(spacing: 10) {
            // Album Art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Playback Controls
            HStack(spacing: 14) {
                Button(action: { musicService.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { musicService.togglePlayPause() }) {
                    Image(systemName: track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { musicService.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)

        // 2. Lyrics / No-lyrics state
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Text("Lyrics")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 24)

            if track.lyrics.isEmpty {
                Text("Lyrics tidak tersedia")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(track.lyrics) { line in
                            let isActive = line.timeSeconds <= track.playbackPosition
                            Text(line.text)
                                .font(.system(size: 11.5, weight: isActive ? .bold : .regular))
                                .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 90)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
