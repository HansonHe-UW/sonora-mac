# Sonora

A lightweight native macOS music player with synced lyrics for local audio files.

Sonora is planned as a native SwiftUI macOS app for local music playback, metadata-based lyric matching, synced lyric display, and local lyric caching.

## Status

This repository currently contains the initial runnable app skeleton. The first slice establishes the app structure, UI shell, core module boundaries, and repeatable build/run workflow. Real file import, AVFoundation playback, online lyric providers, and persistent caching are planned follow-up milestones.

## Tech Stack

- Swift + SwiftUI
- Swift Package Manager
- AVFoundation for future local playback and metadata validation
- URLSession for future lyric provider integrations
- SQLite/GRDB planned for local library and lyric cache persistence

## Audio Format Policy

v1 target formats:

- `.mp3`
- `.m4a`
- `.aac`
- `.wav`
- `.flac`
- `.aiff`
- `.aif`
- `.caf`

v1 unsupported formats:

- `.ncm`
- `.qmc*`
- `.kgm`
- `.mflac0`
- `.ogg`
- `.opus`
- `.ape`
- `.wma`

The future importer will use file extensions only as a first-pass filter. Final acceptance should be based on AVFoundation runtime validation so corrupted, encrypted, DRM-protected, or mislabelled files fail with a clear reason.

## Development

Build and run the macOS app bundle:

```bash
./script/build_and_run.sh
```

Verify the app launches:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
swift test
```

## License

MIT
