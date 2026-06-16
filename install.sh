#!/usr/bin/env bash
# Installs the Claude Quota SwiftBar plugin (Go binary).
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "macOS only." >&2
    exit 1
fi

if ! command -v go >/dev/null 2>&1; then
    echo "Go is required. Install it from https://go.dev/dl/ and re-run." >&2
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

# Resolve the directory containing this script (works for both local checkout
# and curl | bash, where BASH_SOURCE[0] is empty and $0 is just "bash").
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)

REPO_BASE="https://raw.githubusercontent.com/ohlrogge/claude-quota/main"

echo "Go $(go version | awk '{print $3}') found — building binary..."

# Use a local checkout when available; download source files otherwise.
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/go/main.go" ]; then
    BUILD_DIR="$SCRIPT_DIR/go"
else
    BUILD_DIR=$(mktemp -d)
    trap 'rm -rf "$BUILD_DIR"' EXIT
    echo "Downloading source files..."
    for f in go.mod main.go accounts.go api.go render.go; do
        curl -fsSL "$REPO_BASE/go/$f" -o "$BUILD_DIR/$f"
    done
fi

BINARY="$PLUGIN_DIR/claude-quota.5m.cgo"
(cd "$BUILD_DIR" && go build -o "$BINARY" .)
chmod +x "$BINARY"

# Tell SwiftBar to exec the binary directly instead of wrapping it in
# "bash -l -c", which adds an unnecessary shell process every 5 minutes.
METADATA=$(printf '<swiftbar.runInBash>false</swiftbar.runInBash>' | base64)
xattr -w "com.ameba.SwiftBar" "$METADATA" "$BINARY" 2>/dev/null || true

open -a SwiftBar

# Add SwiftBar to Login Items so the gauges survive a reboot.
if ! osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "SwiftBar"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/SwiftBar.app", hidden:false}' >/dev/null 2>&1 \
        || echo "Could not add SwiftBar to Login Items — enable 'Launch at Login' in SwiftBar's preferences instead." >&2
fi

echo
echo "Installed to $BINARY"
echo "If macOS shows a Keychain dialog, click 'Always Allow' so the widget"
echo "can refresh unattended."
