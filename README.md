# Android Virtual Device Manager

A lightweight, interactive Bash script to manage Android Emulators (AVDs) and SDKs without opening Android Studio.

## Features

- 🚀 **Launch Emulators**: Quick or cold boot existing AVDs in the background.
- 📱 **Create Devices**: Interactive wizard to create new AVDs with custom hardware, API levels, and skins.
- 💻 **Developer Tools**:
  - View colored Logcat output (filtered by app or errors).
  - Record screen video and pull it automatically.
  - ADB Wireless pairing.
  - Install APKs via file picker.
- 🛠 **Toolbox**: Wipe data, stop specific devices, delete AVDs, or kill all running emulators.
- ⚙ **SDK Management**: Automatic detection and installation of Android SDK, platform-tools, and system images.

## Installation

### Quick Install
Run the following command in your terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/pvasa/android-virtual-device-manager/main/install.sh | bash
```

### Manual Install
1. Clone the repository:
   ```bash
   git clone https://github.com/pvasa/android-virtual-device-manager.git
   cd android-virtual-device-manager
   ```
2. Run the installer:
   ```bash
   ./install.sh
   ```

### Post-Installation
Ensure your local bin directory is in your `PATH`. Add one of the following to your shell profile (`~/.zshrc` or `~/.bashrc`):

**macOS:**
```bash
export PATH="$HOME/bin:$PATH"
```

**Linux:**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

Simply run the command from your terminal:
```bash
android-manager
```

The script will guide you through setting up the Android SDK if it's not already present on your system.

## Dependencies

The script requires the following tools:
- `java` (JDK 17+ recommended)
- `curl`
- `unzip`
- `git`

It will automatically manage Android SDK components (`sdkmanager`, `avdmanager`, `adb`, `emulator`) once the base dependencies are met.

