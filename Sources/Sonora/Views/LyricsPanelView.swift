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

        lyricsStatusView
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
        ContentUnavailableView(
          "Lyrics Unavailable",
          systemImage: {
            if case .downloadDisabled = reason { return "arrow.down.circle.slash" }
            return "text.quote"
          }(),
          description: Text(reason.displayMessage)
        )
      }
    }
  }

  @ViewBuilder
  private var lyricsStatusView: some View {
    switch state {
    case .loading:
      ProgressView()
        .scaleEffect(0.6)
        .frame(width: 16, height: 16)
    case .empty, .ready, .unavailable:
      EmptyView()
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

    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(lines) { line in
            Text(line.text)
              .id(line.id)
              .font(line.id == highlightedLineID ? .title2.weight(.semibold) : .title3)
              .foregroundStyle(line.id == highlightedLineID ? .primary : .secondary)
              .animation(.easeInOut(duration: 0.18), value: highlightedLineID)
          }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .task(id: highlightedLineID) {
        guard let id = highlightedLineID else { return }
        await Task.yield()
        withAnimation(.easeInOut(duration: 0.25)) {
          proxy.scrollTo(id, anchor: .center)
        }
      }
    }
    .frame(maxHeight: 420)
  }
}
