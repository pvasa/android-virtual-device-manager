#!/bin/bash
set -euo pipefail

URL="https://raw.githubusercontent.com/pvasa/android-virtual-device-manager/main/android-manager.sh"

detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS_TYPE="macOS"
            TARGET_DIR="$HOME/bin"
            TARGET="$TARGET_DIR/android-manager"
            ;;
        Linux*)
            OS_TYPE="Linux"
            TARGET_DIR="$HOME/.local/bin"
            TARGET="$TARGET_DIR/android-manager"
            ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            exit 1
            ;;
    esac
}

detect_os
mkdir -p "$TARGET_DIR"

TEMPFILE=$(mktemp)

# Download the script
if ! curl -fsSL "$URL" -o "$TEMPFILE"; then
    echo "Error: Failed to download $URL" >&2
    rm -f "$TEMPFILE"
    exit 1
fi

# Verify it's a bash script
if ! head -n1 "$TEMPFILE" | grep -q '^#!/bin/bash'; then
    echo "Error: Downloaded file is not a valid bash script" >&2
    rm -f "$TEMPFILE"
    exit 1
fi

if [[ -f "$TARGET" ]]; then
    echo "android-manager already installed at $TARGET. Skipping."
    rm -f "$TEMPFILE"
    exit 0
fi

echo "Installing android-manager to $TARGET (no sudo needed)..."

cp "$TEMPFILE" "$TARGET"
chmod +x "$TARGET"
rm -f "$TEMPFILE"

echo "✅ Successfully installed to $TARGET"
echo ""
echo "To run from anywhere, add this to your shell profile (~/.zshrc, ~/.bashrc, etc.):"
echo ""
if [[ "$OS_TYPE" == "macOS" ]]; then
    echo "export PATH=\"\$HOME/bin:\$PATH\""
else
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo ""
echo "Then run: source ~/.zshrc  (or your shell profile)"
echo ""
echo "Usage: android-manager"
