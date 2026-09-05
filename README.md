<p align="center">
  <img src="Packaging/Assets/SteadyFrame-AppIcon-v3.png" width="128" alt="HiFrame app icon">
</p>

<h1 align="center">HiFrame</h1>

<p align="center">
  A high-refresh-rate assistant for ProMotion MacBooks, aiming to reduce visible flicker in low-brightness gray scenes.
</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="downloads/HiFrame.zip?raw=true"><strong>⬇ Download HiFrame for macOS</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/status-preview-3B82F6" alt="Preview">
</p>

HiFrame is a small macOS menu bar utility for MacBook Pro displays with ProMotion. It continuously presents a nearly invisible 1 × 1-point Metal surface, requesting a 60 or 120 fps presentation cadence during otherwise static content.

This may reduce the visible flicker and discomfort that some users notice in dark gray areas at low brightness.

The interface supports **Follow System**, **English**, and **Simplified Chinese** language options directly from the menu bar. The preview download is ad-hoc signed and not notarized, so macOS may require approval in **System Settings → Privacy & Security** on first launch.

> [!IMPORTANT]
> HiFrame requests a presentation cadence. It does not change the macOS display mode, measure the panel's physical refresh rate, or guarantee a 120 Hz lock. Results vary by Mac, macOS version, content, power state, and viewer.

## Highlights

- Request a 60 or 120 fps cadence while keeping ProMotion enabled.
- Run continuously or only when connected to external power.
- Stop automatically below a configurable battery level.
- Target the built-in display or all connected displays.
- Use a fixed, tiny 8/255 frame-to-frame luminance delta.
- Place the signal at the lower-left, lower-right, or center of the screen.
- Switch between Follow System, English, and Simplified Chinese from the menu bar.
- Optionally launch in the menu bar when you log in to macOS; off by default.
- Check for updates manually and receive new stable-version prompts automatically.
- Choose **Report an Issue…** to open GitHub’s new-issue page in your browser.
- Toggle instantly with `⌃⌥⌘H` and copy runtime diagnostics from the menu bar.

## Launch at login

Enable **Launch at Login** in the menu bar, and click it again to disable. If approval is pending, choose **Approve in System Settings…**; clicking the toggle while approval is pending cancels registration. Each time the menu opens, it reads the actual system status. Login launches still respect the existing enabled state, power policy, and low-battery protection.

Place `HiFrame.app` in a stable location (the Applications folder is recommended) before enabling this option. Configuring login items is unavailable when running via `swift run`.

## Checking for updates

Choose **Check for Updates…** from the menu bar at any time. The app also checks GitHub Releases in the background at startup and while running, at most once every 24 hours. Each new stable version prompts once; manual checks always show the result. Background failures remain silent, and manual failures offer a link to the releases page. Update prompts show the installed and new versions and let you open the release page to download the update; installation remains manual.

## Requirements

- macOS 13 or later
- A MacBook Pro with ProMotion for the intended use case
- A Swift 5.10-compatible toolchain and macOS SDK when building from source

## Build from source

To build the app yourself:

```bash
swift test
./scripts/build-app.sh
open dist/HiFrame.app
```

HiFrame runs only in the menu bar. On first launch it is enabled at 120 fps, targets the built-in display, places the signal at the center, and runs only on external power with a 20% low-battery cutoff.
