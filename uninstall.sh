#!/bin/bash
set -euo pipefail

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

if [[ ! -f "$TARGET" ]]; then
    echo "android-manager not found at $TARGET. Nothing to uninstall."
    exit 0
fi

echo "Uninstalling android-manager from $TARGET..."

rm "$TARGET"

echo "✅ Uninstalled successfully."
echo ""
echo "Optional: Remove PATH export from your shell profile (~/.zshrc, ~/.bashrc, etc.):"
if [[ "$OS_TYPE" == "macOS" ]]; then
    echo "export PATH=\"\$HOME/bin:\$PATH\""
else
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo ""
echo "Then run: source ~/.zshrc  (or your shell profile)"
