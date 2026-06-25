# CHAINFALL

A daily cascade game: **Drop7's chain-reaction × push-your-luck**. Drop numbered discs
into a 7-wide well — a disc pops when its number matches the count of discs in its row or
column, gravity collapses everything, and that re-triggers more pops (a **cascade**). Each
chain link builds an **unbanked heat multiplier**. Tap **Bank** to lock it in, or keep
dropping for a fatter chain while a rising floor threatens to bury you and forfeit it all.

> Sibling to [RUNG](https://github.com/Cole-Will-I-Am/RUNG): reuses its design system
> (Ink/Paper + the gold→red Heat ramp) and its no-Mac TestFlight pipeline, and — because
> it's a pure deterministic grid sim — can later reuse RUNG's server-authoritative
> anti-cheat backend for fair daily leaderboards.

## Status: Milestone 0 (prototype the fun)
First build is a single screen — the well, drop-into-column, animated cascades with
particle pops + haptics, a live heat multiplier, and a Bank button — **no backend, no
daily, no leaderboard**. The only question: does an unzipping cascade feel great, and is
bank-vs-push genuinely tense? If yes, the daily/leaderboard/replay is plumbing already
proven in RUNG.

## Architecture
```
Chainfall/
  project.yml            # XcodeGen (generated in CI; .xcodeproj not committed)
  Package.swift          # Linux/local: compiles + tests the engine via `swift test`
  Chainfall/
    Sources/
      App/      ChainfallApp.swift, root
      Engine/   # PURE-Swift deterministic grid sim (no SpriteKit) — Linux-testable
      Views/    # SwiftUI + SpriteKit (SpriteView) — the well, cascade juice, Bank
      Theme/    Theme.swift  (shared with RUNG's design language)
    Tests/      # XCTest (@testable import Chainfall) — iOS sim in CI
    Assets.xcassets
  CoreTests/    # XCTest (@testable import ChainfallCore) — runs on Linux
```

## Build & ship (no Mac)
Same pattern as RUNG: only `project.yml` committed, XcodeGen runs in CI, signed + uploaded
via the App Store Connect API key.
```bash
swift test                                              # verify the engine off-device
gh workflow run ios-release.yml --ref main -f upload=true
```
