import SwiftUI

struct SettingsView: View {
  @AppStorage("autoDownloadLyrics") private var autoDownloadLyrics = true
  @AppStorage("defaultLyricsOffset") private var defaultLyricsOffset = 0.0
  @AppStorage("experimentalLyricsProxyEnabled") private var experimentalLyricsProxyEnabled = false
  @AppStorage("experimentalLyricsProxyBaseURL") private var experimentalLyricsProxyBaseURL = ""

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
        Text("LRCLIB is enabled by default and does not require an API key.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Toggle("Enable experimental reverse lyrics proxy", isOn: $experimentalLyricsProxyEnabled)

        TextField("Experimental proxy base URL", text: $experimentalLyricsProxyBaseURL)
          .textFieldStyle(.roundedBorder)
          .disabled(!experimentalLyricsProxyEnabled)

        Text("Use this only for personal experiments. Sonora expects a compatible endpoint such as `/v2/musixmatch/lyrics?title=...&artist=...` on the configured base URL.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(20)
    .frame(width: 520)
  }
}
