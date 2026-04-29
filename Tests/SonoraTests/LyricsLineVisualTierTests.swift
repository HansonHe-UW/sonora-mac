import Testing
@testable import Sonora

struct LyricsLineVisualTierTests {
  @Test
  func activeIndexMapsToActiveTier() {
    #expect(LyricsLineVisualTier.tier(for: 3, activeIndex: 3) == .active)
  }

  @Test
  func nearbyIndicesMapToNeighborTier() {
    #expect(LyricsLineVisualTier.tier(for: 1, activeIndex: 3) == .neighbor)
    #expect(LyricsLineVisualTier.tier(for: 4, activeIndex: 3) == .neighbor)
  }

  @Test
  func distantIndicesMapToDistantTier() {
    #expect(LyricsLineVisualTier.tier(for: 0, activeIndex: 3) == .distant)
    #expect(LyricsLineVisualTier.tier(for: 7, activeIndex: 3) == .distant)
  }

  @Test
  func missingActiveIndexFallsBackToDistantTier() {
    #expect(LyricsLineVisualTier.tier(for: 0, activeIndex: nil) == .distant)
  }
}
