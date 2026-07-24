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

## Install

You can copy the release binary somewhere on your `PATH`:

```sh
install .build/release/throttle /usr/local/bin/throttle
```

Commands that apply or remove throttling must be run with `sudo`:

```sh
sudo throttle apply LTE
sudo throttle off
```

Read-only commands do not require elevated privileges:

```sh
throttle list
throttle status
```

## Usage

```sh
throttle list
sudo throttle apply LTE
sudo throttle custom --download 5mbit --upload 1mbit --latency 150ms --packet-loss 1
throttle status
throttle save SlowAPI
throttle delete SlowAPI
sudo throttle off
```

## Commands

### `throttle list`

Lists every discovered profile. Built-in profiles are bundled with the binary.
Saved profiles are loaded from:

```text
~/Library/Application Support/throttle/Profiles/
```

### `sudo throttle apply <profile>`

Applies a built-in or saved profile.

```sh
sudo throttle apply "Very Bad Network"
```

Profile lookup is case-insensitive and ignores spacing/punctuation, so
`verybadnetwork`, `Very Bad Network`, and `very-bad-network` resolve the same
way.

### `sudo throttle custom`

Applies an ad hoc custom profile.

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
dummynet in quick all pipe 12001
dummynet out quick all pipe 12002
```

The anchor name is:

```text
com.apple/throttle
```

This avoids rewriting `/etc/pf.conf` or flushing the system-wide PF ruleset.
When applying a profile, `throttle` configures the two pipes using `dnctl pipe
config` with bandwidth, delay, and packet-loss rate.

If applying rules fails midway, the tool attempts to clean up the throttle
anchor and pipes before reporting the error.

## Notes

- Throttling is host-level, not per-process.
- Loopback traffic is not specially excluded by the current rules.
- VPNs, security tools, or custom PF configurations may affect behavior.
- Automated tests do not run privileged network mutations.
