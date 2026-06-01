# Contributing to Panora

Thanks for your interest in improving Panora! This guide covers how to build,
test, and submit changes.

## Prerequisites

- macOS 14 or later
- Xcode 26 or later (required to run the GUI and produce an `.app` bundle)
- A Last.fm API account (see the README for credential setup)

## Building and running

Panora is a Swift Package with no `.xcodeproj`.

```sh
swift build          # compile-only check, fast feedback loop
open Package.swift    # open in Xcode to actually run the GUI (scheme: Panora)
```

`swift build` only verifies that the code compiles. The app cannot be
meaningfully run from the CLI binary: `MenuBarExtra`, the window scenes, and
SwiftData all need a proper `.app` bundle, so use Xcode (scheme `Panora`, Run).

## Last.fm credentials

For development, set environment variables in the Xcode scheme
(*Edit Scheme → Run → Arguments → Environment Variables*):

- `LASTFM_API_KEY`
- `LASTFM_API_SECRET`

These take priority over the build-time `Secrets.generated.swift`. Never commit
real credentials; `Config.xcconfig` is git-ignored for this reason. See the
README for the full credential-resolution order.

## Running tests

```sh
swift test
```

The suite covers the scrobble engine, Last.fm client, persistence/queue,
`AppState`, the statistics view model, and core models, plus a UI smoke test.
Please keep tests green and add coverage for new behavior.

## Coding conventions

- **Swift language mode is pinned to v5** (`swiftSettings` in `Package.swift`) so
  the adapter's non-`Sendable` callbacks and the `@MainActor` UI layer compile
  without strict-concurrency friction. Keep new concurrency-sensitive code
  main-actor-isolated rather than fighting Swift 6 mode.
- **User-facing strings are in English**; keep new UI and error text consistent.
- **Documentation comments are in English**, using DocC `///` syntax on types and
  public/important members.
- Each Swift source file starts with the SPDX header
  `// SPDX-License-Identifier: GPL-3.0-or-later`.

## Pull requests

1. Fork the repository and create a topic branch.
2. Keep changes focused; one logical change per PR.
3. Ensure `swift build` and `swift test` pass.
4. Describe the motivation and any behavior changes in the PR description.

## License

By contributing, you agree that your contributions will be licensed under the
**GNU General Public License v3.0 or later**, the same license as the project.
