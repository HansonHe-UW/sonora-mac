import SwiftUI

struct ImportSummaryView: View {
  var summary: TrackImportSummary
  var dismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Import Summary")
        .font(.title2.weight(.semibold))

      Text(summary.statusText)
        .foregroundStyle(.secondary)

      if summary.duplicateCount > 0 {
        Text("\(summary.duplicateCount) duplicate track\(summary.duplicateCount == 1 ? " was" : "s were") skipped.")
          .font(.callout)
      }

      if summary.issues.isEmpty {
        Text("No file-level import errors.")
          .font(.callout)
      } else {
        List(summary.issues) { issue in
          VStack(alignment: .leading, spacing: 4) {
            Text(issue.fileName)
              .font(.callout.weight(.medium))

            Text(issue.reason)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
        .frame(minHeight: 180)
      }

      HStack {
        Spacer()

        Button("Close", action: dismiss)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(minWidth: 520, minHeight: 320)
  }
}
