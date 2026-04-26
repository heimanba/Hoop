---
name: ios-debugger-agent
description: Build, launch, screenshot, and debug the Hoop iOS app on Simulator. Use when asked to run Hoop, verify UI changes end-to-end, inspect simulator state, capture screenshots, collect console logs, or diagnose runtime behavior after a SwiftUI/iOS change. Prefer this repo's scripts/build-and-launch.sh workflow.
---

# Hoop iOS Debugger Agent

## Overview

Use this skill for end-to-end Simulator verification in the Hoop app. Prefer the repository script over ad hoc Xcode commands because `AGENTS.md` names it as the canonical launch path.

Project defaults:

- Project: `Hoop.xcodeproj`
- Scheme: `Hoop`
- Default simulator: `iPhone 17`
- Derived data: `.build/DerivedData`
- Default screenshot: `.build/screenshots/hoop.png`
- Bundle id default from the script: `com.example.Hoop`
- Canonical command: `scripts/build-and-launch.sh`

## Core Workflow

### 1) Check the target and simulator assumptions

- Read the user request and identify whether they need a build, launch, screenshot, log capture, or UI diagnosis.
- If the request mentions a specific simulator, pass it with `SIMULATOR_NAME`.
- If no simulator is specified, use the script default.
- If the app's bundle id has changed, pass `BUNDLE_ID` explicitly.

### 2) Build, install, launch, and screenshot

Run from the repo root:

```bash
scripts/build-and-launch.sh
```

Useful overrides:

```bash
SIMULATOR_NAME="iPhone 17 Pro" scripts/build-and-launch.sh
SCREENSHOT_PATH=".build/screenshots/feature-name.png" scripts/build-and-launch.sh
BUNDLE_ID="com.example.Hoop" scripts/build-and-launch.sh
```

The script builds with `xcodebuild`, boots the simulator, installs the app, launches it, and writes a screenshot. Treat the screenshot path printed by the script as the primary visual artifact.

### 3) Inspect runtime state

Use `xcrun simctl` for focused follow-up checks:

```bash
xcrun simctl list devices booted
xcrun simctl get_app_container booted com.example.Hoop app
xcrun simctl io booted screenshot .build/screenshots/hoop-followup.png
xcrun simctl terminate booted com.example.Hoop
xcrun simctl launch booted com.example.Hoop
```

Prefer a named device UDID when multiple simulators are booted.

### 4) Collect logs when behavior is unclear

For launch or runtime diagnosis, capture console output around the failing interaction:

```bash
xcrun simctl spawn booted log stream --style compact --predicate 'process == "Hoop"'
```

Stop log capture once enough evidence is collected. Summarize the relevant lines instead of pasting noisy logs.

### 5) Diagnose failures

- Build failure: read the first meaningful compiler error, fix the source issue, then rerun `scripts/build-and-launch.sh`.
- Missing simulator: confirm the requested simulator exists with `xcrun simctl list devices available`; use `SIMULATOR_NAME` for an available device.
- Install failure: verify the `.app` path under `.build/DerivedData/Build/Products/Debug-iphonesimulator/Hoop.app`.
- Launch failure: confirm `BUNDLE_ID`, then relaunch with `xcrun simctl launch`.
- Blank or wrong screenshot: wait for app launch, retake a screenshot, and check whether the app terminated.

## Validation Standard

For meaningful UI changes, final verification should include:

- The build/launch command that ran.
- Whether the app launched successfully.
- The screenshot path, if captured.
- Any relevant simulator logs or failure details.

If Simulator verification cannot be run, explain the blocker and run the next most relevant build or test command instead.
