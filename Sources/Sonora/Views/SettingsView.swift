import SwiftUI

struct SettingsView: View {
  @AppStorage("autoDownloadLyrics") private var autoDownloadLyrics = true
  @AppStorage("defaultLyricsOffset") private var defaultLyricsOffset = 0.0

  var body: some View {
    Form {
      Section("Lyrics") {
        Toggle("Automatically download lyrics when possible", isOn: $autoDownloadLyrics)

        HStack {
          Text("Default lyrics offset")
          Slider(value: $defaultLyricsOffset, in: -3...3, step: 0.1)
          Text(defaultLyricsOffset, format: .number.precision(.fractionLength(1)))
            .monospacedDigit()
            .frame(width: 42, alignment: .trailing)
          Text("s")
            .foregroundStyle(.secondary)
        }
      }

      Section("Providers") {
        Text("NetEase is currently tried first for online lyrics. Sonora falls back to LRCLIB when NetEase does not return a match.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(20)
    .frame(width: 520)
  }
}
