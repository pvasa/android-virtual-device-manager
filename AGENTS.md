# Agent Guidelines for android-virtual-device-manager

## Commands
- **Run:** `./android-manager.sh` (ensure executable with `chmod +x`)
- **Install:** `./install.sh` (copies to `$HOME/bin` or `$HOME/.local/bin`)
- **Uninstall:** `./uninstall.sh`
- **Lint:** `shellcheck android-manager.sh install.sh uninstall.sh` (Recommended)
- **Test:** Manual verification required. No automated test suite exists.

## Code Style & Conventions
- **Language:** Bash (#!/bin/bash)
- **Formatting:** 4-space indentation. Keep lines under 100 chars where possible.
- **Naming:** `snake_case` for functions and variables. `UPPER_CASE` for globals/constants.
- **Structure:** Use comment headers (e.g., `# --- Section ---`) to organize code.
- **Safety:** Use `set -euo pipefail` in setup scripts. Handle errors gracefully in the main interactive loop.
- **UI/UX:** Use ANSI escape codes for colors (defined in `android-manager.sh`). Provide clear user feedback.
- **Config:** Persist user settings in `$HOME/.android_manager_config`.
- **Dependencies:** Check for `java`, `curl`, `unzip`, `git` before proceeding.

## Architecture
- **Core:** `android-manager.sh` contains all logic for AVD management.
- **Helpers:** `install.sh` and `uninstall.sh` manage the binary placement.
- **State:** Relies on Android SDK tools (`sdkmanager`, `avdmanager`, `adb`) and local config.
