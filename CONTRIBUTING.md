# Contributing to LazyDisk

Thank you for your interest in LazyDisk. This guide covers how to get the project running locally, run tests, build a distributable `.app`, and submit changes.

## Table of contents

- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Development workflow](#development-workflow)
- [Running tests](#running-tests)
- [Building the app bundle](#building-the-app-bundle)
- [Code signing and notarization](#code-signing-and-notarization)
- [Downloading releases](#downloading-releases)
- [Project structure](#project-structure)
- [Commit guidelines](#commit-guidelines)
- [Pull requests](#pull-requests)
- [Reporting issues](#reporting-issues)

## Requirements

| Tool | Version |
|------|---------|
| macOS | 13.0 (Ventura) or later |
| Xcode | 15+ (includes Swift 5.9+) |
| Swift | 5.9+ |

No third-party dependencies — the project uses only Apple frameworks and Swift Package Manager.

## Getting started

```bash
git clone https://github.com/DinonowDev/LazyDisk.git
cd LazyDisk
swift build
.build/debug/LazyDisk
```

For a faster iteration loop during UI work:

```bash
./Scripts/dev.sh
```

## Development workflow

1. **Fork** the repository and create a branch from `main`.
2. **Make focused changes** — one feature or fix per branch when possible.
3. **Run tests** before pushing: `swift test`.
4. **Build the app** to verify the bundle: `./Scripts/build-app.sh`.
5. **Open a pull request** with a clear description of what changed and why.

### Full Disk Access

To scan protected system folders during development, grant Full Disk Access to Terminal (or `LazyDisk.app` after building):

**System Settings → Privacy & Security → Full Disk Access**

## Running tests

```bash
# All tests
swift test

# Verbose output
swift test -v

# Single test class
swift test --filter ByteFormatterTests
```

The test suite includes:

- **Unit tests** for `LazyDiskCore` (formatting, paths, filters, layout engines, localization)
- **Integration tests** for CLI parsing and headless workflows
- **Filesystem E2E tests** against temporary directories

CI runs `swift build`, `swift test`, and `./Scripts/build-app.sh` on every push and pull request (see `.github/workflows/ci.yml`).

## Building the app bundle

```bash
./Scripts/build-app.sh
open dist/LazyDisk.app
```

The script:

1. Builds a release binary with `swift build -c release`
2. Bundles `assets/AppIcon.icns` (or builds from `assets/AppIcon.iconset`)
3. Creates `dist/LazyDisk.app` with `Info.plist` and entitlements from `Scripts/LazyDisk.entitlements`

### Release build without the script

```bash
swift build -c release
.build/release/LazyDisk
```

## Code signing and notarization

For local distribution outside the Mac App Store:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name" ./Scripts/build-app.sh
```

### Notarization (optional)

**Keychain profile (recommended):**

```bash
xcrun notarytool store-credentials "lazydisk-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

NOTARIZE_APP=1 \
NOTARYTOOL_PROFILE="lazydisk-notary" \
CODE_SIGN_IDENTITY="Developer ID Application: Your Name" \
./Scripts/build-app.sh
```

**Environment variables:**

```bash
NOTARIZE_APP=1 \
APPLE_ID="you@example.com" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APPLE_TEAM_ID="TEAMID" \
CODE_SIGN_IDENTITY="Developer ID Application: Your Name" \
./Scripts/build-app.sh
```

## Downloading releases

Pre-built `.app` bundles are published on GitHub Releases:

1. Go to [github.com/DinonowDev/LazyDisk/releases](https://github.com/DinonowDev/LazyDisk/releases)
2. Download the latest `LazyDisk.app` (or `.zip`) for your Mac
3. If macOS blocks the app, right-click → **Open** the first time, or remove the quarantine attribute:

```bash
xattr -cr /path/to/LazyDisk.app
```

CI artifacts from successful builds are also available under the **Actions** tab for each workflow run.

## Project structure

```
Sources/
  LazyDiskCore/     Shared models, parsers, layout engines (no UI)
  LazyDisk/         macOS app — SwiftUI views, services, view models
Tests/
  LazyDiskTests/    Unit, integration, and E2E tests
Scripts/
  build-app.sh      Release .app bundle builder
  dev.sh            Quick dev launch script
  LazyDisk.entitlements
assets/             App icon and preview images
```

**LazyDiskCore** holds logic that must be testable without the GUI (byte formatting, path utilities, chart layout, CLI parsing, localization strings). The app target imports it and adds SwiftUI, filesystem services, and platform APIs.

## Commit guidelines

Use clear, scoped commit messages:

```
feat: add treemap chart drill-down navigation
fix: correct Spotlight fallback when index is stale
test: cover volume filter edge cases
docs: update CLI examples in README
chore: bump CI macOS runner to 14
```

- **feat** — new feature or user-visible behavior
- **fix** — bug fix
- **refactor** — code change without behavior change
- **test** — tests only
- **docs** — documentation only
- **chore** — tooling, CI, build scripts

Keep commits focused: one logical change per commit when possible.

## Pull requests

- Target the `main` branch.
- Ensure `swift test` and `./Scripts/build-app.sh` succeed locally.
- Describe **what** changed and **why**.
- Add screenshots or screen recordings for UI changes when helpful.
- Link related issues if applicable.

## Reporting issues

When filing a bug report, include:

- macOS version
- LazyDisk version or commit hash
- Steps to reproduce
- Expected vs. actual behavior
- Relevant logs or screenshots

For feature requests, describe the problem you want solved and how LazyDisk could address it.

---

Questions? Open a [GitHub Discussion](https://github.com/DinonowDev/LazyDisk/discussions) or an issue on the repository.
