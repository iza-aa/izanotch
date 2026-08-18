import SwiftUI

public struct MusicLyricsPanelView: View {
    @ObservedObject public var musicService: MusicService = .shared
    public var audioLevels: [CGFloat] = [0.3, 0.6, 0.9, 0.5, 0.8, 0.4]

    public init(musicService: MusicService = .shared, audioLevels: [CGFloat] = [0.3, 0.6, 0.9, 0.5, 0.8, 0.4]) {
        self.musicService = musicService
        self.audioLevels = audioLevels
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 1. Now Playing Header & Playback Controls
            HStack(spacing: 10) {
                // Album Art / Visualizer Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(musicService.currentTrack.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(musicService.currentTrack.artist)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Playback Controls
                HStack(spacing: 12) {
                    Button(action: { musicService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { musicService.togglePlayPause() }) {
                        Image(systemName: musicService.currentTrack.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
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
            .padding(.horizontal, 4)

            // 2. Lyrics Stream Panel
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

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(musicService.currentTrack.lyrics) { line in
                            Text(line.text)
                                .font(.system(size: 11.5, weight: line.id == 5 ? .bold : .regular))
                                .foregroundColor(line.id == 5 ? .white : .white.opacity(0.45))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 110)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
}
