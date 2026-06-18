# menu-bar-badges

![menu-bar-badges in the macOS menu bar](docs/menu-bar.png)

*pr-review (left) and claude-quota (right) sitting in the menu bar.*

[SwiftBar](https://github.com/swiftbar/SwiftBar) plugins for the menu bar. The repo ships two:

- **claude-quota** — status gauges for your Claude Code quota, one rounded bar per account.
- **pr-review** — a badge counting GitHub PRs awaiting your review, with a dropdown of those PRs and your own open PRs.

SwiftBar is a free macOS app that runs scripts and binaries on a timer and displays their output in the menu bar. Each plugin is a compiled Go binary it runs every 5 minutes. Install either or both — the [installer](#quick-install) lets you choose.

> Forked from [grzegorz-raczek-unit8/claude-quota](https://github.com/grzegorz-raczek-unit8/claude-quota) and rewritten in Go.

## claude-quota — what it shows

- Each gauge displays the **5-hour-window utilisation** for one account.
- Fill colour shifts as the window fills up: **green** → **yellow** (≥60%) → **orange** (≥75%) → **red** (≥90%).
- When the 5-hour window is fully used, the gauge shows a **countdown to reset** (`4:28`).
- When the **weekly limit** is hit, the gauge turns **black** with a countdown to the weekly reset (`2D`).
- The dropdown lists full detail for every account: 5-hour and weekly windows, per-model windows where your plan reports them, extra-usage credits, and reset times.
- Refreshes every 5 minutes plus a manual **Refresh now** entry.
- If a token is stale, a **Re-authenticate** menu item opens Terminal and runs `claude` directly.

## pr-review — what it shows

- A single badge with the **count of open PRs where your review is requested** (across all of GitHub). The colour escalates with the count: **grey** (0) → **blue** (1–2) → **orange** (3–4) → **red** (5+).
- The dropdown has two sections:
  - **Review requested** — each PR awaiting your review, as a clickable link (with a `[draft]` marker where relevant).
  - **My open PRs** — your own open PRs with a status marker: ✓ approved, ✗ changes requested, ○ review needed, ✎ draft, · open.
- Refreshes every 5 minutes plus a manual **Refresh now** entry.

It uses the GitHub CLI (`gh`), so you need it installed and signed in — see [How pr-review works](#how-pr-review-works). If `gh` is missing or unauthenticated, the dropdown shows a one-time setup hint instead.

## Quick install

Requires macOS and [Homebrew](https://brew.sh). The installer also needs [Go](https://go.dev/dl/) to build, [SwiftBar](https://github.com/swiftbar/SwiftBar) to run the plugins, and — for pr-review — the [GitHub CLI](https://cli.github.com) (`gh`); when run interactively it asks before installing any that are missing via Homebrew.

```sh
curl -fsSL https://raw.githubusercontent.com/ohlrogge/menu-bar-badges/main/install.sh | bash
```

The installer asks which plugins to install. To choose non-interactively (e.g. for `curl | bash`), set `PLUGINS`:

```sh
URL=https://raw.githubusercontent.com/ohlrogge/menu-bar-badges/main/install.sh
curl -fsSL "$URL" | PLUGINS=claude bash      # claude-quota only
curl -fsSL "$URL" | PLUGINS=gh bash          # pr-review only
curl -fsSL "$URL" | PLUGINS=claude,gh bash   # both
```

From a checkout you can instead pass `--claude`, `--gh`, or `--all`. When macOS shows a Keychain permission dialog on the first claude-quota refresh, click **Always Allow**.

## Install from a checkout

```sh
git clone https://github.com/ohlrogge/menu-bar-badges.git
cd menu-bar-badges
./install.sh
```

Both install paths set up [SwiftBar](https://github.com/swiftbar/SwiftBar) via Homebrew if it is not already installed, and add it to Login Items so the badges come back after a reboot.

## How claude-quota works

The plugin reads your Claude Code OAuth token from the macOS Keychain (**read-only** — it never refreshes or rewrites tokens, so it cannot log you out) and queries the same usage endpoint that Claude Code's `/usage` screen uses. No passwords, no scraping, no third-party services.

The binary calls `/usr/bin/security` directly (no `PATH` lookup) and writes cache files with `0600` permissions to `~/.cache/claude-quota/`.

> **Note:** the usage endpoint is internal to Claude Code and undocumented, so a future Claude Code update may require a small fix here.

## How pr-review works

The plugin shells out to the authenticated [GitHub CLI](https://cli.github.com) (`gh`) — there is no token handling in this code. It runs a single `gh api graphql` query for both PR lists and caches the result for 240s in `~/.cache/pr-review/`.

Sign in once with `gh auth login`. The query needs a token with the `repo` and `read:org` scopes — the defaults from `gh auth login` already cover this. If `gh` is missing or unauthenticated, the dropdown shows a setup hint instead of failing.

Because SwiftBar runs plugins without a login shell, the binary resolves `gh` by absolute path (Homebrew, Nix profile, `~/.local/bin`) rather than relying on `PATH`, so it keeps refreshing unattended.

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

Delete the binaries you no longer want from your SwiftBar plugin folder (`~/.swiftbar` by default):

```sh
rm ~/.swiftbar/claude-quota.5m.cgo   # claude-quota
rm ~/.swiftbar/pr-review.5m.cgo      # pr-review
```

To also clear cached data and config:

```sh
rm -rf ~/.cache/claude-quota ~/.cache/pr-review
rm -rf ~/.config/claude-quota        # pinned accounts / hidden list
```

If you no longer use SwiftBar, also remove it from System Settings → General → Login Items.
