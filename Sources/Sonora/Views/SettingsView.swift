import SwiftUI

struct SettingsView: View {
  @AppStorage("autoDownloadLyrics") private var autoDownloadLyrics = true
  @AppStorage("defaultLyricsOffset") private var defaultLyricsOffset = 0.0
  @AppStorage("musixmatchAPIKey") private var musixmatchAPIKey = ""

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
        SecureField("Musixmatch API key", text: $musixmatchAPIKey)
          .textFieldStyle(.roundedBorder)
      }
    }
    .formStyle(.grouped)
    .padding(20)
    .frame(width: 520)
  }
}
