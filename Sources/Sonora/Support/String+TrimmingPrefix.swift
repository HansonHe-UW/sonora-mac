import Foundation

extension String {
  func trimmingPrefix(_ prefix: String) -> String {
    guard hasPrefix(prefix) else { return self }
    return String(dropFirst(prefix.count))
  }

  var trimmedForMetadata: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
