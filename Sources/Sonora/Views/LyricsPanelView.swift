import SwiftUI

struct LyricsPanelView: View {
  var state: LyricsLookupState
  var currentTime: TimeInterval
  @Binding var lyricsOffset: TimeInterval
  var onSeek: ((TimeInterval) -> Void)? = nil
  var onReload: (() -> Void)? = nil
  var onSwitchSource: ((String) -> Void)? = nil

  private let offsetRange: ClosedRange<TimeInterval> = -3...3
  private let offsetStep: TimeInterval = 0.1
  private let reloadHelpText = "Reload lyrics, ignore cache, and keep the current playback position."

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Lyrics")
          .font(.title2.weight(.semibold))

        LyricsOffsetControls(
          offset: $lyricsOffset,
          range: offsetRange,
          step: offsetStep
        )

        Spacer()

        lyricsStatusView
      }

      if case .ready(let result) = state {
        LyricsResultView(
          result: result,
          currentTime: currentTime,
          lyricsOffset: lyricsOffset,
          onSeek: onSeek,
          onReload: onReload,
          onSwitchSource: onSwitchSource,
          reloadHelpText: reloadHelpText
        )
      } else if case .loading(let message) = state {
        LyricsLoadingView(message: message)
      } else if let presentation = LyricsStatePresentation.forState(state) {
        LyricsStateView(
          presentation: presentation,
          onReload: presentation.showsReloadAction ? onReload : nil,
          reloadHelpText: reloadHelpText
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

private struct LyricsLoadingView: View {
  var message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ProgressView()
        .controlSize(.regular)

      Text("Loading Lyrics")
        .font(.headline)

      Text(message)
        .foregroundStyle(.secondary)
    }
    .padding(.top, 8)
  }
}

private struct LyricsStateView: View {
  var presentation: LyricsStatePresentation
  var onReload: (() -> Void)?
  var reloadHelpText: String

  var body: some View {
    ContentUnavailableView {
      Label(presentation.title, systemImage: presentation.systemImage)
    } description: {
      Text(presentation.message)
    } actions: {
      if let onReload {
        Button("Reload Lyrics", action: onReload)
          .help(reloadHelpText)
      }
    }
  }
}

private struct LyricsOffsetControls: View {
  @Binding var offset: TimeInterval
  var range: ClosedRange<TimeInterval>
  var step: TimeInterval

  var body: some View {
    HStack(spacing: 6) {
      Button {
        offset = clampedOffset(offset - step)
      } label: {
        Text("-0.1s")
      }
      .buttonStyle(.borderless)
      .disabled(offset <= range.lowerBound)

      Text(formattedOffset)
        .font(.caption.monospacedDigit().weight(.medium))
        .foregroundStyle(.secondary)
        .frame(minWidth: 46, alignment: .center)

      Button {
        offset = clampedOffset(offset + step)
      } label: {
        Text("+0.1s")
      }
      .buttonStyle(.borderless)
      .disabled(offset >= range.upperBound)

      Button {
        offset = 0
      } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .buttonStyle(.borderless)
      .disabled(isResetDisabled)
      .help("Reset lyrics offset")
    }
    .font(.caption.weight(.medium))
  }

  private var formattedOffset: String {
    if abs(offset) < 0.05 {
      return "0.0s"
    }

    return String(format: "%+.1fs", offset)
  }

  private var isResetDisabled: Bool {
    abs(offset) < 0.05
  }

  private func clampedOffset(_ value: TimeInterval) -> TimeInterval {
    min(max(value, range.lowerBound), range.upperBound)
  }
}

private struct LyricsResultView: View {
  var result: LyricsResult
  var currentTime: TimeInterval
  var lyricsOffset: TimeInterval
  var onSeek: ((TimeInterval) -> Void)?
  var onReload: (() -> Void)?
  var onSwitchSource: ((String) -> Void)?
  var reloadHelpText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      switch result.content {
      case .plain(let text):
        ScrollView {
          Text(text)
            .font(.title3.weight(.regular))
            .foregroundStyle(.primary)
            .lineSpacing(8)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 200)
        }
        .scrollIndicators(.hidden)
        .background(TransientScrollerConfigurator())
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

          if let onReload {
            Button {
              onReload()
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .help(reloadHelpText)
          }
        }

        if let copyrightText = result.attribution.copyrightText, !copyrightText.isEmpty {
          Text(copyrightText)
            .font(.caption)
            .foregroundStyle(.secondary)
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

  private var displayLines: [SyncedLyricsDisplayLine] {
    SyncedLyricsDisplayLines.make(from: lines)
  }

  private var scrollState: SyncedLyricsScrollState {
    SyncedLyricsScrollState(lines: displayLines, currentTime: currentTime, lyricsOffset: lyricsOffset)
  }

  var body: some View {
    let displayLines = displayLines
    let activeLineID = scrollState.activeLineID
    let activeIndex = displayLines.firstIndex { $0.id == activeLineID }

    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(displayLines.enumerated()), id: \.element.id) { index, line in
            let visualTier = LyricsLineVisualTier.tier(for: index, activeIndex: activeIndex)
            HStack {
              Text(line.text)
                .font(font(for: visualTier))
                .foregroundStyle(.primary)
                .opacity(opacity(for: visualTier))
                .lineSpacing(lineSpacing(for: visualTier))
                .scaleEffect(scale(for: visualTier), anchor: .leading)

              Spacer(minLength: 0)
            }
            .id(line.id)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onSeek?(line.time) }
            .padding(.bottom, line.endsSourceLine ? 10 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: activeLineID)
          }
        }
        .padding(.top, 16)
        .padding(.bottom, 200)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
      .background(TransientScrollerConfigurator())
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

  private func font(for tier: LyricsLineVisualTier) -> Font {
    switch tier {
    case .active:
      return .title2.weight(.bold)
    case .neighbor:
      return .title3.weight(.medium)
    case .distant:
      return .title3.weight(.regular)
    }
  }

  private func opacity(for tier: LyricsLineVisualTier) -> Double {
    switch tier {
    case .active:
      return 1
    case .neighbor:
      return 0.58
    case .distant:
      return 0.28
    }
  }

  private func lineSpacing(for tier: LyricsLineVisualTier) -> CGFloat {
    switch tier {
    case .active:
      return 5
    case .neighbor, .distant:
      return 4
    }
  }

  private func scale(for tier: LyricsLineVisualTier) -> CGFloat {
    switch tier {
    case .active:
      return 1
    case .neighbor:
      return 0.985
    case .distant:
      return 0.97
    }
  }
}
