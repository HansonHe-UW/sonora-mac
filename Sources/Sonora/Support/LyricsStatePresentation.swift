import Foundation

struct LyricsStatePresentation: Equatable {
  var title: String
  var message: String
  var systemImage: String
  var showsReloadAction: Bool

  static func forState(_ state: LyricsLookupState) -> LyricsStatePresentation? {
    switch state {
    case .empty:
      return LyricsStatePresentation(
        title: "Lyrics Ready When You Are",
        message: "Select a track or start playback to load cached, local, or online lyrics.",
        systemImage: "text.quote",
        showsReloadAction: false
      )
    case .loading(let message):
      return LyricsStatePresentation(
        title: "Loading Lyrics",
        message: message,
        systemImage: "magnifyingglass",
        showsReloadAction: false
      )
    case .ready:
      return nil
    case .unavailable(let reason):
      switch reason {
      case .noMatch:
        return LyricsStatePresentation(
          title: "No Lyrics Match",
          message: "No cached, local, or online lyrics matched this track yet.",
          systemImage: "text.magnifyingglass",
          showsReloadAction: true
        )
      case .networkFailure:
        return LyricsStatePresentation(
          title: "Lyrics Provider Unreachable",
          message: "Sonora could not reach the lyrics provider. Check your connection and try again.",
          systemImage: "wifi.exclamationmark",
          showsReloadAction: true
        )
      case .downloadDisabled:
        return LyricsStatePresentation(
          title: "Auto-Download Disabled",
          message: "Automatic online lyric lookup is turned off in Settings. Local cache and sidecar LRC files still work.",
          systemImage: "arrow.down.circle.slash",
          showsReloadAction: false
        )
      case .providerError(let detail):
        return LyricsStatePresentation(
          title: "Lyrics Provider Error",
          message: detail.isEmpty ? "The lyrics provider returned an unexpected error." : detail,
          systemImage: "exclamationmark.triangle",
          showsReloadAction: true
        )
      }
    }
  }
}
