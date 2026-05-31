# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Open Scrobbler is a native macOS (SwiftUI) Last.fm scrobbler: it detects what is
playing on the system and submits "now playing" + scrobbles. Menu bar app +
window, with a local history and offline retry queue. It is a Swift Package
(no `.xcodeproj`), opened directly in Xcode.

## Commands

```sh
swift build                 # compile-only check; fast feedback loop
open Package.swift           # open in Xcode to actually RUN the GUI
```

- `swift build` only verifies compilation. The app **cannot be meaningfully run
  from the CLI binary** — `MenuBarExtra`, window scenes, and SwiftData need a
  proper `.app` bundle, so run via Xcode (scheme `OpenScrobbler`, Run).
- There are no tests yet; there is no lint config.
- Last.fm credentials are required at runtime: set `LASTFM_API_KEY` /
  `LASTFM_API_SECRET` (Xcode scheme env vars) or edit `LastfmConfig.swift`.

## Critical constraint: now-playing detection

macOS 15.4+ blocks the private `MediaRemote` API for non-Apple processes. The
app depends on [`ejbills/mediaremote-adapter`](https://github.com/ejbills/mediaremote-adapter)
(pinned to branch `master` in `Package.swift`), which runs the framework through
`/usr/bin/perl` (bundle id `com.apple.perl5`) to bypass the restriction without
disabling SIP. Consequences that constrain all design decisions here:

- The app is **not sandboxable** and **cannot ship on the Mac App Store**.
  Distribution is a Developer ID-signed, notarized `.app`/DMG.
- The adapter spawns a Perl subprocess; detection breaking after an OS update is
  an expected risk and lives entirely behind `NowPlayingMonitor`.

## Architecture

Data flows in one direction, wired together in `AppState`:

```
NowPlayingMonitor → AppState → ScrobbleEngine → LastfmClient
   (adapter)                        │              (HTTP)
                                    └→ ScrobbleStore (SwiftData)
```

- **`AppState`** (`@MainActor @Observable`) is the single coordinator. It owns
  the monitor, engine, and `LastfmClient`, holds auth state, and is injected via
  `.environment(appState)`. It wires `monitor.onUpdate → engine.handle`.
- **`NowPlayingMonitor`** wraps `MediaController` from the adapter. The adapter
  delivers callbacks on the main queue, so the monitor uses
  `MainActor.assumeIsolated` rather than re-dispatching. It maps the raw
  `TrackInfo.Payload` into a `TrackPlayback` (drops entries lacking artist+title).
- **`ScrobbleEngine`** implements Last.fm rules with a **local timer**
  (`scrobbleTask`), not by trusting adapter position updates (which arrive only
  on change). It scrobbles once playback passes `min(duration/2, 240s)` for
  tracks > 30s; identity is `artist|title|album`. Track changes and pause/resume
  cancel/reschedule the task.
- **`LastfmClient`** is an `actor`. Signs requests with `api_sig` (MD5 of sorted
  params + secret, computed *before* adding `format=json`). Auth is the desktop
  token flow: `fetchRequestToken` → open `authorizationURL` in browser →
  `fetchSession`. Note `validate()` checks the JSON `error` key first, because
  Last.fm returns API errors with HTTP 200.
- **Persistence**: `ScrobbleEntry` (`@Model`) + `ScrobbleStore` (`@MainActor`).
  Every scrobble is inserted as `pending`, then `flushQueue()` sends sendable
  entries (pending/failed, attempts < 5) and marks them `sent`/`failed`. This is
  the offline retry mechanism; it runs after each scrobble and on app start.

## Conventions specific to this codebase

- Swift language mode is pinned to **v5** (`swiftSettings` in `Package.swift`) to
  keep the adapter's non-`Sendable` callbacks and the `@MainActor` UI layer
  compiling without strict-concurrency friction. Keep new concurrency-sensitive
  code main-actor-isolated rather than fighting Swift 6 mode.
- User-facing strings are in **Italian**; keep new UI/error text consistent.
- The Keychain stores `username\nsessionKey` as a single generic-password item
  (`KeychainStore`).

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
