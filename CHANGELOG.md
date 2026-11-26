# Changelog

## v0.1.0 — Initial Release

First public open-source release of **Ren** *(Swedish: clean, pure)* — a lightweight (~1.4 MB), frosted-glass macOS cleaner powered by a parallel Rust engine and native SwiftUI.

### Highlights
- **Native SwiftUI + Rust Architecture**: Frosted-glass translucent window with One Dark Pro / Monokai vibrant accents, liquid-glass controls, and a live donut chart — no Electron, no background daemons, zero telemetry.
- **Live Gradual Scan**: Scans categories progressively with real-time slice animation and center storage tally while keeping the layout anchored.
- **Smart & Advanced Modes**:
  - **Smart Scan**: App Caches, System Logs, Trash Bin, and Uninstalled App Leftovers.
  - **Advanced Scan**: Developer Toolchains (Xcode DerivedData, CoreSimulator, Homebrew, Cargo, Yarn/npm, NuGet, Gradle), Containers & VMs (Docker Desktop, Buildx, Colima), Apple Mail Downloads & iOS Backups, and Stale Large Downloads.
- **Safe by Default**: All deletions use macOS's native Trash (`NSFileManager`), symlinks are never followed (`lstat`), and advanced targets are opt-in.
- **Floating Desktop Widget & Menu Bar Extra**: Collapse into a 220×240 floating desktop widget or trigger rescans right from the macOS menu bar.
- **Audited & Verified**: Zero memory leaks under macOS `/usr/bin/leaks`, panic-safe C-ABI boundary, and full Rust + Swift unit test suites.

### Installation
1. Download `Ren-v0.1.0-macos-universal.dmg` (or `.zip`) from the assets below.
2. Drag **Ren.app** into your **Applications** folder.
3. Because this release is ad-hoc signed (not notarized with a paid Apple Developer ID), right-click **Ren.app** ➔ **Open** on first launch (or run `xattr -cr /Applications/Ren.app`).
