#!/usr/bin/env bash
# Installs the SwiftBar plugins from this repo (compiled Go binaries).
#
# Plugins:
#   claude-quota  — Claude Code usage gauges in the menu bar
#   pr-review     — GitHub PRs awaiting your review (needs the gh CLI)
#
# Choose what to install interactively, or non-interactively with either
# flags (--claude / --gh / --all) or the PLUGINS env var (e.g. PLUGINS=claude,gh).
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "macOS only." >&2
    exit 1
fi

# ---- choose plugins -------------------------------------------------------
INSTALL_CLAUDE=false
INSTALL_GH=false

for arg in "$@"; do
    case "$arg" in
        --claude) INSTALL_CLAUDE=true ;;
        --gh|--pr|--pr-review) INSTALL_GH=true ;;
        --all|--both) INSTALL_CLAUDE=true; INSTALL_GH=true ;;
    esac
done

if [ -n "${PLUGINS:-}" ]; then
    case ",$PLUGINS," in *,claude,*|*,claude-quota,*) INSTALL_CLAUDE=true ;; esac
    case ",$PLUGINS," in *,gh,*|*,pr,*|*,pr-review,*)  INSTALL_GH=true ;; esac
fi

if [ "$INSTALL_CLAUDE" = false ] && [ "$INSTALL_GH" = false ]; then
    if [ -t 0 ]; then
        echo "Which plugins do you want to install?"
        echo "  1) claude-quota  — Claude Code usage gauges"
        echo "  2) pr-review     — GitHub PRs awaiting your review"
        echo "  3) both (default)"
        printf "Choice [3]: "
        read -r choice
        case "$choice" in
            1) INSTALL_CLAUDE=true ;;
            2) INSTALL_GH=true ;;
            *) INSTALL_CLAUDE=true; INSTALL_GH=true ;;
        esac
    else
        echo "No selection given; installing both (use PLUGINS=claude or PLUGINS=gh to choose)."
        INSTALL_CLAUDE=true; INSTALL_GH=true
    fi
fi

# ---- prerequisites --------------------------------------------------------
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

if [ "$INSTALL_GH" = true ]; then
    if ! command -v gh >/dev/null 2>&1; then
        if command -v brew >/dev/null; then
            echo "Installing GitHub CLI (gh)..."
            brew install gh
        else
            echo "The pr-review plugin needs the GitHub CLI. Install it from https://cli.github.com" >&2
            exit 1
        fi
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "Note: you are not signed in to GitHub. Run 'gh auth login' once so the"
        echo "pr-review plugin can fetch your PRs."
    fi
fi

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [ -z "$PLUGIN_DIR" ]; then
    PLUGIN_DIR="$HOME/.swiftbar"
    defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"
fi
mkdir -p "$PLUGIN_DIR"

# ---- resolve source -------------------------------------------------------
# Resolve the directory containing this script (works for both local checkout
# and curl | bash, where BASH_SOURCE[0] is empty and $0 is just "bash").
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)

REPO_URL="https://github.com/ohlrogge/menu-bar-badges.git"

echo "Go $(go version | awk '{print $3}') found — building..."

# Use a local checkout when available; shallow-clone the repo otherwise. (The
# multi-binary layout spans subdirectories, so per-file curl no longer fits.)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/go/go.mod" ]; then
    BUILD_DIR="$SCRIPT_DIR/go"
else
    CLONE_DIR=$(mktemp -d)
    trap 'rm -rf "$CLONE_DIR"' EXIT
    echo "Cloning source..."
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    BUILD_DIR="$CLONE_DIR/go"
fi

# ---- build ----------------------------------------------------------------
# Tell SwiftBar to exec the binary directly instead of wrapping it in
# "bash -l -c", which adds an unnecessary shell process on every refresh.
RUN_IN_BASH=$(printf '<swiftbar.runInBash>false</swiftbar.runInBash>' | base64)

build_plugin() {
    local pkg="$1" out="$2"
    local binary="$PLUGIN_DIR/$out"
    (cd "$BUILD_DIR" && go build -o "$binary" "./cmd/$pkg")
    chmod +x "$binary"
    xattr -w "com.ameba.SwiftBar" "$RUN_IN_BASH" "$binary" 2>/dev/null || true
    echo "Installed $binary"
}

if [ "$INSTALL_CLAUDE" = true ]; then
    build_plugin claude-quota "claude-quota.5m.cgo"
fi
if [ "$INSTALL_GH" = true ]; then
    build_plugin pr-review "pr-review.5m.cgo"
fi

open -a SwiftBar

# Add SwiftBar to Login Items so the menu bar items survive a reboot.
if ! osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "SwiftBar"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/SwiftBar.app", hidden:false}' >/dev/null 2>&1 \
        || echo "Could not add SwiftBar to Login Items — enable 'Launch at Login' in SwiftBar's preferences instead." >&2
fi

echo
if [ "$INSTALL_CLAUDE" = true ]; then
    echo "claude-quota: if macOS shows a Keychain dialog, click 'Always Allow' so the"
    echo "widget can refresh unattended."
fi
