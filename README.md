# Sleepless

A tiny macOS menu bar app that keeps your Mac awake. No Electron, no dependencies — just a single Swift file.

<img width="200" alt="sleepless-menu" src="https://github.com/user-attachments/assets/placeholder.png">

## Features

- **Menu bar icon** — moon (inactive) / coffee cup (active)
- **Timed or infinite** — 30min, 1hr, 2hr, 4hr, 8hr, or forever
- **Countdown in menu bar** — see remaining time at a glance
- **Native API** — uses `IOPMAssertion` (same API as `caffeinate`)
- **App Store compatible** — no subprocess spawning, fully sandboxed
- **~120 KB** — single Swift file, compiles in seconds

## Install

### From source (recommended)

```bash
git clone https://github.com/slooops/Sleepless.git
cd Sleepless
./build.sh
cp -r Sleepless.app /Applications/
```

### Start on login

System Settings > General > Login Items > click `+` > select Sleepless

## How it works

Sleepless uses macOS's `IOPMAssertionCreateWithName` API to create a power assertion that prevents display and system idle sleep. This is the same underlying API that the built-in `caffeinate` command uses, but called directly — no subprocess needed.

When you stop keeping awake (or the timer runs out), the assertion is released and your Mac resumes its normal sleep behavior.

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon or Intel

## Building

Just run `./build.sh`. It compiles a single Swift file with `swiftc` — no Xcode project needed.

If you want to open it in Xcode, just open `Sleepless.swift` directly.

## License

MIT
