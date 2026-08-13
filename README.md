# throttle

`throttle` is a native macOS command-line utility for simulating constrained
network conditions during local development and testing. It is intentionally
CLI-only: no GUI, no menu bar app, and no background daemon.

The implementation uses macOS packet filtering and traffic shaping facilities:
`pfctl` loads a dedicated dummynet anchor, and `dnctl` configures dummynet pipes
for download and upload shaping.

## Requirements

- macOS 13 or newer
- Swift 6
- Administrator privileges for commands that modify network rules

## Quick Start

Clone the repo, build the debug binary, and list the bundled profiles:

```sh
git clone https://github.com/odd-theory/throttle.git
cd throttle
swift build
.build/debug/throttle list
```

Start throttling with a foreground session:

```sh
sudo .build/debug/throttle apply LTE
```

`throttle` will stay open and show the active profile. Press `Ctrl-C` to disable
throttling and return to your shell.

To apply throttling and immediately return to the shell instead:

```sh
sudo .build/debug/throttle apply LTE --detach
.build/debug/throttle status
sudo .build/debug/throttle off
```

## Build

```sh
swift build -c release
```

The release binary will be available at:

```sh
.build/release/throttle
```

For local development, use:

```sh
swift build
swift test
```

## Local Testing

Start with commands that do not change network state:

```sh
swift build
swift test
.build/debug/throttle list
.build/debug/throttle status
```

Then test real throttling with a mild profile:

```sh
sudo .build/debug/throttle apply LTE
```

This starts a foreground session that shows the active profile and elapsed time.
Use a browser, `curl`, or the app you are testing, then press `Ctrl-C` to remove
the throttling rules and return to your shell.

If you want the old set-and-return behavior, use `--detach`:

```sh
sudo .build/debug/throttle apply LTE --detach
.build/debug/throttle status
sudo .build/debug/throttle off
```

Avoid starting with `Offline` or `100% Loss` until you trust the cleanup path on
your machine.

To test a custom profile:

```sh
sudo .build/debug/throttle custom \
  --download 5mbit \
  --upload 1mbit \
  --latency 150ms \
  --packet-loss 1
```

To apply a custom profile and then save it from another command, use detached
mode:

```sh
sudo .build/debug/throttle custom \
  --download 5mbit \
  --upload 1mbit \
  --latency 150ms \
  --packet-loss 1 \
  --detach

.build/debug/throttle save SlowAPI
sudo .build/debug/throttle off
```

You can also run `apply` without a profile to choose interactively:

```sh
sudo .build/debug/throttle apply
```

The selector supports Up/Down, Enter, and number keys. Typing a number
pre-selects that profile, then Enter applies it.

## Install

You can copy the release binary somewhere on your `PATH`:

```sh
swift build -c release
sudo install .build/release/throttle /usr/local/bin/throttle
```

Commands that apply or remove throttling must be run with `sudo`:

```sh
sudo throttle apply LTE
sudo throttle apply LTE --detach
sudo throttle off
```

Read-only commands do not require elevated privileges:

```sh
throttle list
throttle status
```

## Homebrew Packaging

`throttle` should be distributed as a Homebrew formula, not a cask. Casks are
mainly for `.app`, `.pkg`, fonts, and GUI-style installs. A SwiftPM CLI binary
belongs in a formula.

This repository includes a release workflow that publishes the Homebrew formula
when changes land on `main`.

Expected branch flow:

1. Create feature branches from `dev`.
2. Open feature PRs back into `dev`.
3. When `dev` is ready for release, open a PR from `dev` to `main`.
4. Merge that PR to `main`.
5. The `Publish Homebrew formula` workflow builds, tests, creates the release
   tag from `VERSION`, computes the source tarball checksum, and publishes the
   formula to the Odd Theory tap.

The tap repository must exist before merging to `main`:

```text
odd-theory/homebrew-tap
```

The `odd-theory/throttle` repository also needs a GitHub Actions secret named:

```text
HOMEBREW_TAP_TOKEN
```

That token must be able to write to `odd-theory/homebrew-tap`.

The generated formula is based on:

```text
packaging/homebrew/Formula/throttle.rb.template
```

After the workflow publishes the formula, users can install with:

```sh
brew tap odd-theory/tap
brew install throttle
```

The published formula will look like this after the workflow substitutes the
release tag and source checksum:

```rb
class Throttle < Formula
  desc "Native macOS CLI for simulating constrained network conditions"
  homepage "https://github.com/odd-theory/throttle"
  url "https://github.com/odd-theory/throttle/archive/refs/tags/VERSION_TAG.tar.gz"
  sha256 "SOURCE_TARBALL_SHA256"
  license "MIT"

  depends_on xcode: ["16.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/throttle"
  end

  test do
    assert_match "WiFi", shell_output("#{bin}/throttle list")
  end
end
```

To test a generated formula locally from the tap repository:

```sh
brew install --build-from-source ./Formula/throttle.rb
brew test throttle
brew uninstall throttle
```

## CI/CD

The repository has two GitHub Actions workflows:

- `CI` runs `swift build` and `swift test` on pull requests to `dev` and `main`,
  and on pushes to `dev` and `main`.
- `Publish Homebrew formula` runs on pushes to `main` and manual dispatch. It
  builds and tests the package, creates `v<VERSION>` if needed, computes the
  GitHub source tarball SHA256, and commits `Formula/throttle.rb` to
  `odd-theory/homebrew-tap`.

For the initial release, `VERSION` is `0.1.0`, so merging `dev` to `main` will
publish tag `v0.1.0`.

## Usage

```sh
throttle list
sudo throttle apply LTE
sudo throttle apply
sudo throttle apply LTE --detach
sudo throttle custom --download 5mbit --upload 1mbit --latency 150ms --packet-loss 1
throttle status
throttle save SlowAPI
throttle delete SlowAPI
sudo throttle off
```

## Commands

### `throttle list`

Lists every discovered profile. Built-in profiles are bundled with the binary.
Profiles are ordered from best connection to worst connection using bandwidth,
latency, and packet-loss values.
Saved profiles are loaded from:

```text
~/Library/Application Support/throttle/Profiles/
```

### `sudo throttle apply <profile>`

Applies a built-in or saved profile and starts a foreground session.

```sh
sudo throttle apply "Very Bad Network"
```

The foreground session keeps running until you press `Ctrl-C`. On exit,
`throttle` removes its PF anchor and dummynet pipes, then marks the status
inactive.

Profile lookup is case-insensitive, ignores spacing/punctuation, and accepts
unique partial names. These resolve to the same profile:

```sh
sudo throttle apply "Lossy Network"
sudo throttle apply Lossy Network
sudo throttle apply lossy
```

If a partial name matches multiple profiles, `throttle` reports the ambiguous
matches instead of guessing.

Use `--detach` when you want to apply the profile and return to the shell:

```sh
sudo throttle apply LTE --detach
```

### `sudo throttle apply`

Opens an interactive profile selector and applies the chosen profile directly.

Use Up/Down to move, Enter to apply, `q` to cancel, or type a profile number to
pre-select it before pressing Enter.

### `sudo throttle custom`

Applies an ad hoc custom profile and starts a foreground session.

```sh
sudo throttle custom \
  --download 5mbit \
  --upload 1mbit \
  --latency 150ms \
  --packet-loss 1
```

Supported bandwidth units:

- `bit`
- `kbit`
- `mbit`
- `gbit`
- `bps`
- `kbps`
- `mbps`
- `gbps`

Latency is specified in milliseconds, for example `150ms`.

Packet loss is a percentage from `0` through `100`.

Use `--detach` to apply a custom profile and return to the shell:

```sh
sudo throttle custom \
  --download 5mbit \
  --upload 1mbit \
  --latency 150ms \
  --packet-loss 1 \
  --detach
```

### `throttle status`

Displays whether throttling is active and shows the current profile values:

- current profile
- download limit
- upload limit
- latency
- packet loss

### `sudo throttle off`

Flushes the throttle PF anchor, deletes throttle dummynet pipes, releases the
stored PF enable token when available, and marks the tool inactive.

### `throttle save <name>`

Saves the currently active custom profile.

Only custom profiles can be saved. Built-in and already-saved profiles are
already available through `throttle list`.

### `throttle delete <name>`

Deletes a saved profile from Application Support. Built-in profiles cannot be
deleted.

## Built-In Profiles

The default profiles use clear condition names similar to Network Link
Conditioner-style presets:

- `100% Loss`
- `3G`
- `DSL`
- `EDGE`
- `High Latency`
- `Lossy Network`
- `LTE`
- `Offline`
- `Very Bad Network`
- `WiFi`

Profiles are not hardcoded in Swift. They are JSON files bundled from:

```text
Sources/ThrottleCore/Profiles/
```

## Profile Format

Each profile is a JSON file with this shape:

```json
{
  "name": "LTE",
  "download": "50mbit",
  "upload": "10mbit",
  "latency": "60ms",
  "packetLoss": 0.1
}
```

To add a user profile manually, place a `.json` file in:

```text
~/Library/Application Support/throttle/Profiles/
```

Saved profiles with the same normalized name as a built-in profile take
precedence.

## Architecture

The package is split into a tiny executable target and a reusable core target:

- `Sources/throttle/main.swift` wires command-line arguments to the service.
- `Sources/ThrottleCore/Commands/` parses commands and formats CLI output.
- `Sources/ThrottleCore/Models/` contains typed profile values and validation.
- `Sources/ThrottleCore/ProfileStore/` discovers profiles and persists status.
- `Sources/ThrottleCore/Networking/` applies and removes macOS network rules.
- `Sources/ThrottleCore/Utilities/` contains shared errors and shell execution.

The networking layer depends on a small `ShellRunning` protocol so tests can
verify generated `pfctl` and `dnctl` commands without requiring root or changing
the host network.

## Networking Implementation

`throttle` uses two dummynet pipes:

- pipe `12001` for inbound traffic
- pipe `12002` for outbound traffic

The tool loads these rules into the stock macOS dummynet anchor point:

```pf
dummynet in quick all no state pipe 12001
dummynet out quick all no state pipe 12002
```

The anchor name is:

```text
com.apple/throttle
```

This avoids rewriting `/etc/pf.conf` or flushing the system-wide PF ruleset.
When applying a profile, `throttle` configures the two pipes using `dnctl pipe
config` with bandwidth, delay, and packet-loss rate.

The rules use `no state` so existing PF states do not keep dummynet behavior
after the rules are removed.

When disabling throttling, `throttle` first resets both throttle pipes to
pass-through behavior (`bw 0`, `delay 0ms`, `plr 0`), then flushes the throttle
PF anchor and deletes the pipes. Resetting before deletion prevents queued or
state-associated traffic from continuing to feel throttled after `off`.

If applying rules fails midway, the tool attempts to clean up the throttle
anchor and pipes before reporting the error.

## Notes

- Throttling is host-level, not per-process.
- Loopback traffic is not specially excluded by the current rules.
- VPNs, security tools, or custom PF configurations may affect behavior.
- Automated tests do not run privileged network mutations.
- If connectivity still feels throttled after `off`, run `sudo throttle off`
  again. It is idempotent and repeats the pass-through reset plus cleanup.
