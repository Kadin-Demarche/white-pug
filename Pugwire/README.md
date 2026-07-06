# Pugwire

A free, open-source, menu-bar bandwidth monitor for macOS — a small alternative
to [GlassWire](https://www.glasswire.com) for people who just want to see
**which processes on their Mac are using the network, right now**, without a
subscription, an account, or a black box.

Pugwire lives in your menu bar, shows live download/upload totals, a rolling
history graph, and a per-process breakdown. That's the whole product.

## Why this exists

GlassWire is a genuinely useful tool, but it's proprietary and increasingly
paywalled. Something this simple — reading network counters your own Mac
already tracks and drawing a graph — doesn't need to be closed-source or
subscription-gated. Pugwire is built so anyone can read every line of it,
build it themselves, and trust exactly what it does.

## Privacy stance

- **No network requests, ever.** Pugwire doesn't phone home, check for
  updates, send analytics, or resolve anything remotely. Grep the source —
  there is no `URLSession`, no socket client code, nothing.
- **No telemetry, no crash reporting, no accounts.**
- **All history is local and human-readable.** Bandwidth history is stored as
  plain JSON Lines at `~/Library/Application Support/Pugwire/history.jsonl`.
  Open it in any text editor.
- **Small surface area.** The whole app is a couple hundred lines of Swift
  across a dozen files — auditable in an afternoon.

## Features (v0.1)

- Live download/upload totals in the menu bar.
- A dropdown dashboard with a rolling history chart and a per-process list
  (icon, name, live ↓/↑ rate), sorted busiest-first.
- Local-only history persisted across restarts (30-day retention by default).
- Adjustable polling interval, optional launch-at-login, and a debug mode
  that logs raw sampler output for troubleshooting.

## How it works

Per-process network attribution on macOS normally requires either a kernel
extension or a `NEFilterDataProvider` system extension (the approach real
firewalls like [Objective-See's LuLu](https://objective-see.org/products/lulu.html)
use). Both require an Apple Developer Program membership, code signing,
notarization, and a system-extension approval flow — a lot of ceremony for a
personal, zero-cost, build-it-yourself tool.

Instead, Pugwire's v0.1 shells out to the `nettop` command line tool that
ships with every Mac (`Sources/Pugwire/Monitoring/NettopSampler.swift`), which
reports cumulative bytes in/out per process without any special entitlement.
Pugwire polls it, converts the cumulative counters into per-second rates
(`BandwidthAggregator.swift`), resolves each pid to a name/icon, and rolls
totals up into minute buckets for the history chart
(`UsageHistoryStore.swift`).

This keeps the project buildable and runnable by anyone with just Xcode's
command line tools — no paid developer account, no kernel extensions, no
notarization required to use it yourself.

### Roadmap: a v2 based on Network Extension

`nettop`'s output format isn't a stable, documented API, and it only shows
counters, not per-connection detail (remote host, ports) the way GlassWire's
paid tiers do. A `NEFilterDataProvider`-based system extension (see LuLu's
source for prior art) would give more accurate, connection-level data and is
the natural next step for contributors who want to take this further.

## Requirements

- macOS 14 (Sonoma) or later.
- Xcode command line tools (`xcode-select --install`) — a full Xcode
  installation is **not** required.

## Building and running

```bash
git clone <this repo>
cd Pugwire

# Option A: run directly for development
./Scripts/run-dev.sh

# Option B: build a real .app bundle
./Scripts/build-app.sh
open dist/Pugwire.app
```

`build-app.sh` ad-hoc signs the app so it will launch locally, but it is not
notarized (that requires a paid Apple Developer account). On first launch,
right-click `Pugwire.app` and choose **Open** to get past Gatekeeper's
"unidentified developer" warning — a one-time step for any unsigned,
un-notarized build.

There's no separate `.xcodeproj` — this is a plain Swift Package. You can
also open the `Pugwire/` folder directly in Xcode (File → Open) and it will
treat `Package.swift` as the project.

## Known limitations / help wanted

This was built and written without access to a real Mac to compile or run it
against — **it has not yet been built or tested on real hardware.** If you
try it and something doesn't work, especially around `nettop`'s output
format (which can vary across macOS versions), please open an issue or a PR.
Specific things worth checking:

- Whether `nettop -P -x -J bytes_in,bytes_out` produces the header/row shape
  `NettopSampler.swift` expects on your macOS version. Enable "Log raw
  nettop output to Console" in Settings (or set the `debugNettopLogging`
  default) and compare against what the parser expects.
- Whether an unprivileged Pugwire can see other users' processes, or only
  your own — `nettop` may need to run as root for full system visibility on
  a shared/multi-user Mac.
- Whether macOS prompts for a "Local Network" permission the first time
  Pugwire runs `nettop`; if so, allow it.

## Contributing

Issues and PRs welcome. The codebase is intentionally small and
dependency-free (no third-party Swift packages) to keep it easy to audit —
please keep it that way.

## License

MIT — see [LICENSE](LICENSE).
