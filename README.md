# Sonora

A lightweight, native macOS music player with synced lyrics for local audio files.

Sonora provides a seamless playback experience for your local music collection, automatically matching metadata with online providers to fetch high-quality synced lyrics and album artwork. Built entirely in Swift and SwiftUI, it offers a fast, native, and beautiful interface.

![Sonora Screenshot](https://raw.githubusercontent.com/HansonHe-UW/sonora-mac/main/images/screenshot.png) *(Note: Replace with actual screenshot path if available)*

## Features

- **Native macOS Interface**: Built from the ground up with SwiftUI for a modern, fluid, and responsive native experience.
- **Synced Lyrics**: Automatically fetches and displays time-synced lyrics (LRC format) for your tracks.
- **Smart Lyric Matching**: 
  - Integrates with **NetEase Cloud Music** (prioritized) and **LRCLIB**.
  - Built-in **Traditional to Simplified Chinese conversion** ensures accurate lyric matching even when track metadata uses traditional characters.
  - Fail-safe fallback to plain text lyrics if time-synced ones are unavailable.
  - Instantly switch or retry sources if a match is incorrect.
- **Smart Artwork Fetching**: Automatically fetches missing album covers from iTunes, using smart scoring to correctly distinguish between studio albums, live versions, and compilations.
- **Local Library Management**: 
  - Drag-and-drop or select folders to import local audio files.
  - Persistent library state saves your queue, tracks, and local caches across launches.
  - Real-time search to instantly filter your library by title, artist, or album.
  - One-click library clearing to start fresh.
- **Offline Caching**: Lyrics and artwork are cached locally so they load instantly on subsequent plays without needing a network connection.

## Tech Stack

- **UI Framework**: Swift 6 + SwiftUI
- **Audio Engine**: AVFoundation for robust local playback and metadata extraction
- **Networking**: URLSession for API integrations
- **Persistence**: File-based JSON snapshots and dedicated local caching stores
- **Testing**: Swift Testing framework

## Supported Audio Formats

Sonora currently supports importing and playing the following DRM-free audio formats:

- `.mp3`
- `.m4a`
- `.aac`
- `.wav`
- `.flac`
- `.aiff` / `.aif`
- `.caf`

*(Note: Encrypted, DRM-protected, or unsupported proprietary formats like `.ncm` and `.qmc*` will be automatically skipped during import.)*

## Development

Build and run the macOS app bundle directly:

```bash
./script/build_and_run.sh
```

Verify the app launches (dry run):

```bash
./script/build_and_run.sh --verify
```

Run the complete test suite:

```bash
swift test
```

## License

MIT
