import SwiftUI

struct LyricsPanelView: View {
  var state: LyricsLookupState
  var currentTime: TimeInterval

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Lyrics")
          .font(.title2.weight(.semibold))

        Spacer()

        Label("Provider-ready", systemImage: "cloud")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      switch state {
      case .empty:
        Text("Lyrics will appear here after local cache, LRC, or online provider lookup.")
          .foregroundStyle(.secondary)

      case .loading(let message):
        ProgressView(message)

      case .ready(let result):
        LyricsResultView(result: result, currentTime: currentTime)

      case .unavailable(let reason):
        ContentUnavailableView("Lyrics Unavailable", systemImage: "text.quote", description: Text(reason))
      }
    }
  }
}

private struct LyricsResultView: View {
  var result: LyricsResult
  var currentTime: TimeInterval

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      switch result.content {
      case .plain(let text):
        Text(text)
          .font(.title3)
          .foregroundStyle(.primary)
          .textSelection(.enabled)
      case .synced(let lines):
        SyncedLyricsView(lines: lines, currentTime: currentTime)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Source: \(result.attribution.displayName)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)

        if let copyrightText = result.attribution.copyrightText, !copyrightText.isEmpty {
          Text(copyrightText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let backlinkURLString = result.attribution.backlinkURLString,
           let backlinkURL = URL(string: backlinkURLString) {
          Link("Open lyrics source", destination: backlinkURL)
            .font(.caption)
        }
      }
    }
  }
}

private struct SyncedLyricsView: View {
  var lines: [LyricsLine]
  var currentTime: TimeInterval

  private var highlightedLineID: LyricsLine.ID? {
    lines.last { $0.time <= currentTime }?.id ?? lines.first?.id
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(lines) { line in
        Text(line.text)
          .font(line.id == highlightedLineID ? .title2.weight(.semibold) : .title3)
          .foregroundStyle(line.id == highlightedLineID ? .primary : .secondary)
          .animation(.easeInOut(duration: 0.18), value: highlightedLineID)
      }
    }
  }
}
