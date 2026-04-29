import SwiftUI

struct PlayerBarView: View {
  @ObservedObject var playerCore: PlayerCore

  var body: some View {
    HStack(spacing: 18) {
      Button {
        playerCore.playPrevious()
      } label: {
        Image(systemName: "backward.fill")
      }
      .buttonStyle(.borderless)
      .help("Previous track")

      Button {
        playerCore.togglePlayPause()
      } label: {
        Image(systemName: playerCore.playbackState == .playing ? "pause.fill" : "play.fill")
          .frame(width: 18)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .help(playerCore.playbackState == .playing ? "Pause" : "Play")

      Button {
        playerCore.playNext()
      } label: {
        Image(systemName: "forward.fill")
      }
      .buttonStyle(.borderless)
      .help("Next track")

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(playerCore.currentTrack?.title ?? "No track")
            .font(.callout.weight(.medium))
            .lineLimit(1)

          Spacer()

          Text("\(TimeFormatter.playbackTime(playerCore.currentTime)) / \(TimeFormatter.playbackTime(playerCore.currentTrack?.duration))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }

        Slider(
          value: Binding(
            get: { playerCore.progress },
            set: { playerCore.seek(to: $0) }
          ),
          in: 0...1
        )
        .help("Playback position")
      }

      Slider(value: $playerCore.volume, in: 0...1) {
        Image(systemName: "speaker.wave.2.fill")
      }
      .frame(width: 130)
      .help("Volume")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }
}
