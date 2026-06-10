#!/usr/bin/env bash
# Installs the Claude Quota SwiftBar plugin.
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "macOS only." >&2
    exit 1
fi

if [ ! -d "/Applications/SwiftBar.app" ]; then
    if ! command -v brew >/dev/null; then
        echo "Homebrew is required to install SwiftBar: https://brew.sh" >&2
        exit 1
    fi
    echo "Installing SwiftBar..."
    brew install --cask swiftbar
fi

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [ -z "$PLUGIN_DIR" ]; then
    PLUGIN_DIR="$HOME/.swiftbar"
    defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"
fi
mkdir -p "$PLUGIN_DIR"

# Copy the plugin from a local checkout, or download it when piped (curl | bash)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/claude-quota.5m.py" ]; then
    cp "$SCRIPT_DIR/claude-quota.5m.py" "$PLUGIN_DIR/"
else
    curl -fsSL \
        "https://raw.githubusercontent.com/grzegorz-raczek-unit8/claude-quota/main/claude-quota.5m.py" \
        -o "$PLUGIN_DIR/claude-quota.5m.py"
fi
chmod +x "$PLUGIN_DIR/claude-quota.5m.py"

open -a SwiftBar
echo
echo "Installed to $PLUGIN_DIR/claude-quota.5m.py"
echo "If macOS shows a Keychain dialog, click 'Always Allow' so the widget"
echo "can refresh unattended."
