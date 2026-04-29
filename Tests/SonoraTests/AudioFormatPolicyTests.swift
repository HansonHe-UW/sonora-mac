import Testing
@testable import Sonora

struct AudioFormatPolicyTests {
  @Test
  func supportedExtensionsAreCaseInsensitive() {
    #expect(AudioFormatPolicy.isSupportedExtension("MP3"))
    #expect(AudioFormatPolicy.isSupportedExtension(".m4a"))
    #expect(AudioFormatPolicy.isSupportedExtension(" FLAC "))
  }

  @Test
  func privatePlatformFormatsAreKnownUnsupported() {
    #expect(AudioFormatPolicy.isKnownUnsupportedExtension("ncm"))
    #expect(AudioFormatPolicy.isKnownUnsupportedExtension("qmcflac"))
    #expect(AudioFormatPolicy.isKnownUnsupportedExtension(".kgm"))
  }
}
