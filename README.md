# claude-quota

Menu bar status gauges for your Claude Code quota — one rounded bar per account, with a live percentage and colour-coded fill.

> Forked from [grzegorz-raczek-unit8/claude-quota](https://github.com/grzegorz-raczek-unit8/claude-quota) and rewritten in Go.

## What it shows

- Each gauge displays the **5-hour-window utilisation** for one account.
- Fill colour shifts as the window fills up: **green** → **yellow** (≥60%) → **orange** (≥75%) → **red** (≥90%).
- When the 5-hour window is fully used, the gauge shows a **countdown to reset** (`4:28`).
- When the **weekly limit** is hit, the gauge turns **black** with a countdown to the weekly reset (`2D`).
- The dropdown lists full detail for every account: 5-hour and weekly windows, per-model windows where your plan reports them, extra-usage credits, and reset times.
- Refreshes every 5 minutes plus a manual **Refresh now** entry.
- If a token is stale, a **Re-authenticate** menu item opens Terminal and runs `claude` directly.

## Quick install

Requires macOS, [Homebrew](https://brew.sh), and [Go](https://go.dev/dl/).

```sh
curl -fsSL https://raw.githubusercontent.com/ohlrogge/claude-quota/main/install.sh | bash
```

When macOS shows a Keychain permission dialog on the first refresh, click **Always Allow**.

## Install from a checkout

```sh
git clone https://github.com/ohlrogge/claude-quota.git
cd claude-quota
./install.sh
```

Both install paths set up [SwiftBar](https://github.com/swiftbar/SwiftBar) via Homebrew if it is not already installed, and add it to Login Items so the gauges come back after a reboot.

## How it works

The plugin reads your Claude Code OAuth token from the macOS Keychain (**read-only** — it never refreshes or rewrites tokens, so it cannot log you out) and queries the same usage endpoint that Claude Code's `/usage` screen uses. No passwords, no scraping, no third-party services.

The binary calls `/usr/bin/security` directly (no `PATH` lookup) and writes cache files with `0600` permissions to `~/.cache/claude-quota/`.

> **Note:** the usage endpoint is internal to Claude Code and undocumented, so a future Claude Code update may require a small fix here.

## Accounts

By default the plugin auto-discovers accounts: every `~/.claude` / `~/.claude-*` config directory that has a Claude Code Keychain entry gets a gauge, labelled by the directory suffix (`~/.claude-work` → `W`). A single auto-discovered account shows no letter label — just the bar.

To pin or rename accounts, create `~/.config/claude-quota/accounts` with one `path [label]` per line:

```
~/.claude-work Work
~/.claude-priv Priv
```

To hide an account's menu bar gauge (its dropdown detail stays), use **Hide from menu bar** in the dropdown — or edit `~/.config/claude-quota/hidden` (one label per line).

Multiple accounts via `CLAUDE_CONFIG_DIR` look like this in your shell rc:

```sh
claude()      { CLAUDE_CONFIG_DIR="$HOME/.claude-work" command claude "$@"; }
claude-priv() { CLAUDE_CONFIG_DIR="$HOME/.claude-priv" command claude "$@"; }
```

## Uninstall

Delete the binary from your SwiftBar plugin folder (`~/.swiftbar` by default):

```sh
rm ~/.swiftbar/claude-quota.5m.cgo
```

If you no longer use SwiftBar, also remove it from System Settings → General → Login Items.
