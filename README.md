# Android Virtual Device Manager

A simple command-line tool to manage Android Virtual Devices (AVDs).

## Prerequisites

Before using this tool, ensure you have:

- Android SDK installed
- `ANDROID_HOME` or `ANDROID_SDK_ROOT` environment variable set
- Android SDK Command-line Tools installed
- Android Emulator installed

## Installation

1. Clone this repository:
```bash
git clone https://github.com/pvasa/android-virtual-device-manager.git
cd android-virtual-device-manager
```

2. Make the script executable (if not already):
```bash
chmod +x android-manager.sh
```

## Usage

### List all available AVDs
```bash
./android-manager.sh list
```

### Create a new AVD
```bash
./android-manager.sh create
```
Follow the interactive prompts to create a new AVD.

### Start an AVD
```bash
./android-manager.sh start <avd-name>
```

Example:
```bash
./android-manager.sh start Pixel_5_API_33
```

### Stop a running AVD
```bash
./android-manager.sh stop <avd-name>
```

Example:
```bash
./android-manager.sh stop Pixel_5_API_33
```

### Delete an AVD
```bash
./android-manager.sh delete <avd-name>
```

Example:
```bash
./android-manager.sh delete Pixel_5_API_33
```

### Show AVD information
```bash
./android-manager.sh info <avd-name>
```

Example:
```bash
./android-manager.sh info Pixel_5_API_33
```

### List available system images and packages
```bash
./android-manager.sh packages
```

### Show help
```bash
./android-manager.sh help
```

## Features

- ✅ List all available AVDs
- ✅ Create new AVDs interactively
- ✅ Start AVDs in the background
- ✅ Stop running AVDs
- ✅ Delete AVDs with confirmation
- ✅ Display detailed AVD information
- ✅ List available system images and packages
- ✅ Color-coded output for better readability
- ✅ Error handling and validation

## License

Apache License 2.0 - See LICENSE file for details