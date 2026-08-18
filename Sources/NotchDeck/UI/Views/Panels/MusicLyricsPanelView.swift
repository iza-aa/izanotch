import SwiftUI

public struct MusicLyricsPanelView: View {
    @ObservedObject public var musicService: MusicService

    public init(musicService: MusicService = .shared) {
        self.musicService = musicService
    }

    public var body: some View {
        VStack(spacing: 10) {
            if musicService.isLoading {
                loadingView
            } else if let track = musicService.currentTrack {
                trackView(track)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await musicService.fetchCurrentTrack() }
        }
    }

    // MARK: - Sub-views

    /// State when no track or Spotify is not running.
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "music.slash")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.25))

            Text(musicService.musicError ?? "Spotify belum terhubung")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button(action: {
                Task { await musicService.fetchCurrentTrack() }
            }) {
                Label("Coba Lagi", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .scaleEffect(0.9)
                .tint(.white.opacity(0.6))
            Text("Menghubungkan ke Spotify...")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func trackView(_ track: MusicTrack) -> some View {
        VStack(spacing: 10) {
            // 1. Now Playing Header & Playback Controls
            HStack(spacing: 12) {
                // Album Art
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                // Playback Controls
                HStack(spacing: 16) {
                    Button(action: { musicService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { musicService.togglePlayPause() }) {
                        Image(systemName: track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { musicService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            // 2. Lyrics / No-lyrics state (Fills bottom area)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                    Text("Lyrics")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                if track.lyrics.isEmpty {
                    VStack {
                        Spacer()
                        Text("Lyrics tidak tersedia")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(track.lyrics) { line in
                                let isActive = line.timeSeconds <= track.playbackPosition
                                Text(line.text)
                                    .font(.system(size: 12, weight: isActive ? .bold : .regular, design: .rounded))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
