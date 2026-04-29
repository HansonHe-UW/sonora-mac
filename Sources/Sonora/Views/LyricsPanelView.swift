import SwiftUI

struct LyricsPanelView: View {
  var state: LyricsLookupState
  var currentTime: TimeInterval
  var lyricsOffset: TimeInterval = 0
  var onSeek: ((TimeInterval) -> Void)? = nil
  var onReload: (() -> Void)? = nil
  var onSwitchSource: ((String) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Lyrics")
          .font(.title2.weight(.semibold))

        if let onReload {
          Button(action: onReload) {
            Image(systemName: "arrow.clockwise")
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .help("Reload lyrics and ignore cache")
        }

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
        LyricsResultView(
          result: result,
          currentTime: currentTime,
          lyricsOffset: lyricsOffset,
          onSeek: onSeek,
          onSwitchSource: onSwitchSource
        )

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
  var lyricsOffset: TimeInterval
  var onSeek: ((TimeInterval) -> Void)?
  var onSwitchSource: ((String) -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      switch result.content {
      case .plain(let text):
        ScrollView {
          Text(text)
            .font(.title3)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 64)
        }
      case .synced(let lines):
        SyncedLyricsView(lines: lines, currentTime: currentTime, lyricsOffset: lyricsOffset, onSeek: onSeek)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text("Source: \(result.attribution.displayName)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            
          if let onSwitchSource {
            Button("Try different source") {
              onSwitchSource(result.attribution.providerName)
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
          }
        }

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
  var lyricsOffset: TimeInterval
  var onSeek: ((TimeInterval) -> Void)?

  @State private var scrollPolicy = SyncedLyricsScrollPolicy()

  private var scrollState: SyncedLyricsScrollState {
    SyncedLyricsScrollState(lines: lines, currentTime: currentTime, lyricsOffset: lyricsOffset)
  }

  var body: some View {
    let activeLineID = scrollState.activeLineID

    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          ForEach(lines) { line in
            let isActive = line.id == activeLineID
            Text(line.text)
              .id(line.id)
              .font(isActive ? .title2.weight(.bold) : .title3.weight(.regular))
              .foregroundStyle(.primary)
              .opacity(isActive ? 1.0 : 0.35)
              .scaleEffect(isActive ? 1.0 : 0.97, anchor: .leading)
              .animation(.spring(response: 0.45, dampingFraction: 0.82), value: activeLineID)
              .onTapGesture { onSeek?(line.time) }
              .contentShape(Rectangle())
          }
        }
        .padding(.top, 16)
        .padding(.bottom, 200)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.12),
            .init(color: .black, location: 0.88),
            .init(color: .clear, location: 1)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .task(id: scrollState) {
        await Task.yield()

        switch scrollPolicy.update(to: scrollState) {
        case .initialPlacement(let id):
          proxy.scrollTo(id, anchor: .center)
        case .activeLineChange(let id):
          withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            proxy.scrollTo(id, anchor: .center)
          }
        case nil:
          break
        }
      }
    }
    .frame(maxHeight: .infinity)
  }
}
