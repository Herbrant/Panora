# Panora

Native macOS (SwiftUI) scrobbler that detects playing music and submits it to **Last.fm**.
Menu bar app + window, with history, statistics, and an offline retry queue.

## How detection works

Since macOS 15.4, Apple has restricted the private `MediaRemote` API to Apple processes only.
Panora uses [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), which
bypasses the restriction by running the framework through `/usr/bin/perl`
(bundle id `com.apple.perl5`, still authorized) **without disabling SIP**.
This allows detecting any player (Apple Music, Spotify, browsers…).

Consequence: the app depends on a private framework, so it is **not sandboxable and cannot be
distributed on the Mac App Store**. Distribution is via a signed and notarized `.app` (Developer ID).

## Requirements

- macOS 14+
- Xcode 26+ (to run the GUI and produce the `.app` bundle)
- A Last.fm API account

## 1. Last.fm API keys

Create an app at <https://www.last.fm/api/account/create>. You will get an
**API key** and a **shared secret**. Panora resolves them in this priority
(first wins):

1. **Environment variables** `LASTFM_API_KEY` / `LASTFM_API_SECRET` — best for
   development and tests; set them in the Xcode scheme
   (*Edit Scheme → Run → Arguments → Environment Variables*).
2. **`Secrets.generated.swift`**, generated from a config file at build time —
   best for release builds. Copy `Config.template.xcconfig` → `Config.xcconfig`,
   fill in the real values, then run `./Scripts/generate-secrets.sh` (or add it as
   a Run Script build phase). `Config.xcconfig` is git-ignored.
3. Otherwise the placeholder values leave the app unconfigured and sign-in disabled.

## 2. Running

Build from the command line (compilation check):

```sh
swift build
```

To run the GUI, open the package in Xcode and press Run:

```sh
open Package.swift
```

> Correct operation of `MenuBarExtra`/window and SwiftData requires an `.app` bundle:
> use Xcode (scheme `Panora`). The binary produced by `swift build` is only for
> verifying compilation.

Run the tests with:

```sh
swift test
```

## 3. Last.fm sign-in

In *Settings* in the main window:
1. **Sign in with Last.fm** — opens the browser on the app authorization page.
2. After authorizing, **I've completed sign-in** — finishes the login and saves the
   session key in the **Keychain**.

## Scrobble rules

- `track.updateNowPlaying` on every track change.
- `track.scrobble` when the track passes **50% of its duration or 4 minutes**
  (whichever is less), only for tracks > 30s. A local timer drives the threshold.
- If submission fails (offline), the scrobble stays queued and is retried
  (up to 5 attempts) on restart or the next scrobble.

## Structure

```
Sources/Panora/
  PanoraApp.swift                   entry point (MenuBarExtra + Window)
  AppState.swift                    coordinator (auth, wiring, source filtering)
  NowPlaying/
    TrackPlayback.swift             current track snapshot
    NowPlayingMonitor.swift         adapter wrapper
    KnownMusicApps.swift            curated player/browser bundle IDs
  Scrobbling/
    LastfmConfig.swift              API keys + credentials
    LastfmClient.swift              Last.fm API + api_sig signing
    KeychainStore.swift             session key in Keychain
    ScrobbleEngine.swift            now-playing/scrobble rules + queue
    StatsModels.swift               statistics value types
  Persistence/
    ScrobbleEntry.swift             SwiftData model
    ScrobbleStore.swift             SwiftData access/queue
  UI/
    MainWindowView.swift            window root + navigation
    HistoryView.swift               scrobble history
    StatisticsView.swift            statistics dashboard
    StatisticsViewModel.swift       dashboard data loading
    StatisticsComponents.swift      dashboard support views
    SettingsView.swift              account + source settings
    MenuBarView.swift               menu bar popover
    OnboardingView.swift            first-run sign-in
    AppSourceSetupView.swift        first-run source selection
    CursorModifiers.swift           hover cursor helper
```

## Out of scope (v1)

Metadata editing/blocking, other services (ListenBrainz, Libre.fm, CSV/JSONL),
Discord Rich Presence, notarization/DMG.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build, test, and pull-request guidance.

## License

Copyright © 2026 Davide Carnemolla.

Panora is free software, licensed under the **GNU General Public License v3.0 or
later** (`GPL-3.0-or-later`). See [LICENSE](LICENSE).
