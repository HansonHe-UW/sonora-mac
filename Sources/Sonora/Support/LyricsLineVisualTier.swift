import Foundation

enum LyricsLineVisualTier: Equatable {
  case active
  case neighbor
  case distant

  static func tier(for index: Int, activeIndex: Int?) -> LyricsLineVisualTier {
    guard let activeIndex else { return .distant }

    let distance = abs(index - activeIndex)
    switch distance {
    case 0:
      return .active
    case 1...2:
      return .neighbor
    default:
      return .distant
    }
  }
}
