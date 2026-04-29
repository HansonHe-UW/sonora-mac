import AppKit
import SwiftUI

struct TrackArtworkView: View {
  var artworkData: Data?
  var cornerRadius: CGFloat
  var iconSize: CGFloat

  var body: some View {
    Group {
      if let artworkImage {
        Image(nsImage: artworkImage)
          .resizable()
          .scaledToFill()
      } else {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(.quaternary)
          .overlay {
            Image(systemName: "music.note")
              .font(.system(size: iconSize, weight: .medium))
              .foregroundStyle(.secondary)
          }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }

  private var artworkImage: NSImage? {
    guard let artworkData else { return nil }
    return NSImage(data: artworkData)
  }
}
