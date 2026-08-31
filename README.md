# pi-kit

A declarative Pi setup for coding work. It installs the latest `@earendil-works/pi-coding-agent`, keeps exactly two Pi packages, and applies a repeatable long-session/tool policy on Linux, macOS, and Windows.

The managed Pi packages are:

- `pi-hashline-edit-pro` for stale-safe, hash-anchored `read`, `replace`, and `insert`
- `pi-web-access` for lightweight web search and HTML-to-Markdown retrieval

## One-Click Install or Sync

The script is completely self-contained. On fresh machines without Node.js, it automatically installs a portable Node.js 22 LTS runtime without requiring `sudo`/root permissions. In Mainland China, it automatically detects the network and uses high-speed mirrors (npmmirror) for Node.js, npm, and Playwright.

### Linux / macOS (Forgejo self-hosted entry)

```sh
curl -fsSL 'https://git.aiatechco.com:31443/zji996/pi-kit/raw/branch/main/install.sh' | sh -s -- --sync
```

*(Optional: add `--cn` to force domestic mirror mode: `... | sh -s -- --sync --cn`)*

### GitHub fallback

```sh
curl -fsSL 'https://raw.githubusercontent.com/zji996/pi-kit/main/install.sh' | sh -s -- --sync
```

### Windows PowerShell

```powershell
irm 'https://git.aiatechco.com:31443/zji996/pi-kit/raw/branch/main/install.ps1' | iex
```

*(Optional: force domestic mirror mode: `& ([scriptblock]::Create((irm 'https://git.aiatechco.com:31443/zji996/pi-kit/raw/branch/main/install.ps1'))) -Sync -Cn`)*

### From a local clone

```sh
./sync.sh
```

## Declarative result

The canonical settings are [`settings.unix.json`](settings.unix.json) and [`settings.windows.json`](settings.windows.json). Sync applies:

- `defaultThinkingLevel: high`
- compaction reserve `32768`, recent context `40000`, branch reserve `32768`
- built-ins `read/bash/edit/write` on Unix or `read/powershell/edit/write` on Windows; `grep/find/ls` are excluded
- only `npm:pi-hashline-edit-pro` and `npm:pi-web-access`
- the managed `playwright-cli` skill
- hashline auto-read enabled and `anchor_grep` disabled
- zero self-referential symlinks; automatically symlinks `pi` and `playwright` into `~/.local/bin`

Packages outside the manifest, including old `pi-subagents` entries, are removed through `pi remove`. A changed settings file is backed up under `~/.pi/agent/backups/` before the canonical file replaces it.

Sync never reads or writes `auth.json`, `models.json`, `models-store.json`, `sessions/`, or project-local Pi state. These files remain machine-specific.

For legacy additive behavior without settings replacement or package cleanup:

```sh
./install.sh --additive
```

## Tool workflow

Use hashline `read/replace/insert` for precise edits and stale-anchor protection. Use `bash` with `rg`, `fd`, Git, compilers, and repository checks for discovery and automation. Use `pi-web-access` for static web content and the managed Playwright skill for SPAs, screenshots, traces, or existing end-to-end tests.

See [`docs/context-budget-guide.md`](docs/context-budget-guide.md) for the compaction and prompt-cache policy.

## Verify

```sh
./scripts/check.sh
./scripts/test-install.sh
pi list
```

The isolated test starts from dirty packages and settings, checks exact convergence and a second idempotent run, and verifies protected files byte-for-byte.

## License

MIT
