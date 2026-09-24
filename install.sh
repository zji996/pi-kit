#!/bin/sh
set -eu

PI_NPM_NAME='@earendil-works/pi-coding-agent'
PI_NPM_PACKAGE="$PI_NPM_NAME@latest"
MINIMUM_PI_VERSION='0.84.4'
PLAYWRIGHT_NPM_PACKAGE='playwright@latest'
PACKAGES='
npm:pi-semantic-edit
npm:pi-web-access
'
MODE='sync'

info() {
  printf '%s\n' "pi-kit: $*"
}

fail() {
  printf '%s\n' "pi-kit: error: $*" >&2
  exit 1
}

FORCE_CN=0

usage() {
  printf '%s\n' 'Usage: install.sh [--sync|--additive] [--cn]'
  printf '%s\n' '  --sync      replace settings and remove packages outside packages.list (default)'
  printf '%s\n' '  --additive  only add or update packages; preserve all existing settings'
  printf '%s\n' '  --cn        force using npmmirror for high-speed download in Mainland China'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sync) MODE='sync' ;;
    --additive) MODE='additive' ;;
    --cn) FORCE_CN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

# Ensure ~/.local/bin is in PATH for portable tool resolution
mkdir -p "${HOME:?HOME is required}/.local/bin"
LOCAL_BIN_ON_PATH=1
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) LOCAL_BIN_ON_PATH=0; export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

# Persist ~/.local/bin in existing shell rc files that do not mention it yet.
persist_local_bin_path() {
  for rc_file in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.zshrc"; do
    if [ -f "$rc_file" ] && ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc_file"
      info "added ~/.local/bin to PATH in $rc_file"
    fi
  done
}

# Link a tool into ~/.local/bin unless it already lives there. Only symlinks
# are replaced, so a real executable placed there by the user is never clobbered.
link_into_local_bin() {
  tool_path=$1
  link_path="${HOME}/.local/bin/$2"
  [ -n "$tool_path" ] && [ "$tool_path" != "$link_path" ] || return 0
  if [ -L "$link_path" ] || [ ! -e "$link_path" ]; then
    ln -sf "$tool_path" "$link_path" 2>/dev/null || true
  else
    info "leaving existing $link_path untouched; $2 resolves to $tool_path"
  fi
}

# Smart domestic mirror selection (fallback to npmmirror for Mainland China users)
NPM_REGISTRY=${NPM_REGISTRY:-''}
NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-''}
if [ "${PI_KIT_MIRROR:-}" = 'cn' ] || [ "$FORCE_CN" = '1' ]; then
  info "China mirror mode enabled; using npmmirror for high-speed download"
  NPM_REGISTRY='https://registry.npmmirror.com'
  NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-'https://npmmirror.com/mirrors/node'}
  export PLAYWRIGHT_DOWNLOAD_HOST=${PLAYWRIGHT_DOWNLOAD_HOST:-'https://npmmirror.com/mirrors/playwright/'}
elif [ -z "$NPM_REGISTRY" ]; then
  if curl -m 1.5 -fsSL "https://registry.npmmirror.com" >/dev/null 2>&1; then
    if ! curl -m 1.2 -fsSL "https://registry.npmjs.org" >/dev/null 2>&1; then
      info "mainland China network detected; using npmmirror for high-speed download"
      NPM_REGISTRY='https://registry.npmmirror.com'
      NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-'https://npmmirror.com/mirrors/node'}
      export PLAYWRIGHT_DOWNLOAD_HOST=${PLAYWRIGHT_DOWNLOAD_HOST:-'https://npmmirror.com/mirrors/playwright/'}
    else
      NPM_REGISTRY='https://registry.npmjs.org'
      NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-'https://nodejs.org/dist'}
    fi
  else
    NPM_REGISTRY='https://registry.npmjs.org'
    NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-'https://nodejs.org/dist'}
  fi
else
  NODE_DIST_MIRROR=${NODE_DIST_MIRROR:-'https://nodejs.org/dist'}
fi

# Zero-dependency Node.js bootstrap for fresh machines without root/sudo
ensure_node_environment() {
  need_node=0
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    need_node=1
  else
    if ! node -e '
      const [major, minor] = process.versions.node.split(".").map(Number);
      if (major < 22 || (major === 22 && minor < 19)) process.exit(1);
    ' 2>/dev/null; then
      need_node=1
    fi
  fi

  if [ "$need_node" -eq 1 ]; then
    info "Node.js 22.19.0+ is required; auto-installing portable Node.js..."
    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch_name=$(uname -m)

    case "$os_name" in
      linux) node_os="linux" ;;
      darwin) node_os="darwin" ;;
      *) fail "Unsupported OS for automatic Node.js bootstrap: $os_name. Please install Node.js 22.19+ manually." ;;
    esac

    case "$arch_name" in
      x86_64|amd64) node_arch="x64" ;;
      aarch64|arm64) node_arch="arm64" ;;
      *) fail "Unsupported architecture for automatic Node.js bootstrap: $arch_name. Please install Node.js 22.19+ manually." ;;
    esac

    ext="tar.xz"
    if [ "$node_os" = "darwin" ] || ! command -v xz >/dev/null 2>&1; then
      ext="tar.gz"
    fi

    node_version="v22.22.0"
    node_dist_name="node-${node_version}-${node_os}-${node_arch}"
    node_url="${NODE_DIST_MIRROR}/${node_version}/${node_dist_name}.${ext}"
    node_target_dir="${HOME}/.local/lib/nodejs/${node_dist_name}"
    tmp_archive="${TMPDIR:-/tmp}/${node_dist_name}.${ext}"

    info "downloading portable Node.js from $node_url"
    mkdir -p "${HOME}/.local/lib/nodejs" "${HOME}/.local/bin" "${TMPDIR:-/tmp}"
    curl -fsSL "$node_url" -o "$tmp_archive" || fail "failed to download Node.js from $node_url"

    rm -rf "$node_target_dir"
    mkdir -p "$node_target_dir"
    if [ "$ext" = "tar.xz" ]; then
      tar -xJf "$tmp_archive" -C "${HOME}/.local/lib/nodejs"
    else
      tar -xzf "$tmp_archive" -C "${HOME}/.local/lib/nodejs"
    fi
    rm -f "$tmp_archive"

    ln -sf "$node_target_dir/bin/node" "${HOME}/.local/bin/node"
    ln -sf "$node_target_dir/bin/npm" "${HOME}/.local/bin/npm"
    ln -sf "$node_target_dir/bin/npx" "${HOME}/.local/bin/npx"

    persist_local_bin_path

    info "installed portable Node.js $(node -v) to $node_target_dir"
  fi
}

ensure_node_environment

version_at_least() {
  node -e '
    const current = process.argv[1].split(".").map(Number);
    const minimum = process.argv[2].split(".").map(Number);
    for (let i = 0; i < 3; i += 1) {
      if ((current[i] || 0) > (minimum[i] || 0)) process.exit(0);
      if ((current[i] || 0) < (minimum[i] || 0)) process.exit(1);
    }
  ' "$1" "$2"
}

# Global npm installs need a writable prefix. System Node.js (for example
# /usr from a distro package) is root-owned, so fall back to ~/.local instead
# of failing with EACCES or requiring sudo.
npm_prefix=$(npm prefix --global)
npm_prefix_probe="$npm_prefix/lib/node_modules"
[ -e "$npm_prefix_probe" ] || npm_prefix_probe="$npm_prefix/lib"
[ -e "$npm_prefix_probe" ] || npm_prefix_probe="$npm_prefix"
if [ ! -w "$npm_prefix_probe" ]; then
  info "npm global prefix $npm_prefix is not writable; installing global tools under ~/.local"
  npm_prefix="${HOME}/.local"
  export npm_config_prefix="$npm_prefix"
fi
npm_bin="$npm_prefix/bin"

# Prefer the executable from the npm prefix that this run installs into. A
# PATH lookup can hit a stale ~/.local/bin link, for example one left pointing
# at a previous nvm Node.js version, which would never be upgraded.
resolve_tool() {
  if [ -x "$npm_bin/$1" ]; then
    printf '%s\n' "$npm_bin/$1"
  else
    command -v "$1" 2>/dev/null || true
  fi
}

pi_bin=$(resolve_tool pi)
installed_version='0.0.0'
if [ -n "$pi_bin" ]; then
  installed_version=$("$pi_bin" --version 2>/dev/null || printf '0.0.0')
fi

latest_version=$(npm view "$PI_NPM_NAME" version --registry "$NPM_REGISTRY" 2>/dev/null || true)
if [ -z "$pi_bin" ]; then
  info 'installing latest Pi'
  npm install --global --ignore-scripts --registry "$NPM_REGISTRY" "$PI_NPM_PACKAGE"
elif ! version_at_least "$installed_version" "$MINIMUM_PI_VERSION"; then
  info "upgrading Pi from $installed_version to latest"
  npm install --global --ignore-scripts --registry "$NPM_REGISTRY" "$PI_NPM_PACKAGE"
elif [ -n "$latest_version" ] && [ "$installed_version" != "$latest_version" ]; then
  info "upgrading Pi from $installed_version to $latest_version"
  npm install --global --ignore-scripts --registry "$NPM_REGISTRY" "$PI_NPM_PACKAGE"
else
  info "Pi $installed_version is current"
fi

pi_bin=$(resolve_tool pi)
[ -n "$pi_bin" ] || fail "Pi was installed, but no executable was found in $npm_bin or on PATH."

# Ensure pi is always accessible directly from ~/.local/bin without self-referential symlink
link_into_local_bin "$pi_bin" pi
if [ "$LOCAL_BIN_ON_PATH" -eq 0 ]; then
  persist_local_bin_path
fi

agent_dir=${PI_CODING_AGENT_DIR:-"${HOME:?HOME is required}/.pi/agent"}
settings_file="$agent_dir/settings.json"
mkdir -p "$agent_dir" "$agent_dir/npm"

# Configure internal npm registry for pi plugin installs
if [ -n "$NPM_REGISTRY" ]; then
  printf 'registry=%s\n' "$NPM_REGISTRY" > "$agent_dir/npm/.npmrc"
fi

if [ "$MODE" = 'sync' ] && [ -f "$settings_file" ]; then
  node - "$settings_file" <<'NODE' | while IFS= read -r package; do
const { readFileSync } = require("node:fs");

const desired = new Set(["npm:pi-semantic-edit", "npm:pi-web-access"]);
const settings = JSON.parse(readFileSync(process.argv[2], "utf8"));
const entries = Array.isArray(settings.packages) ? settings.packages : [];

function sourceOf(entry) {
  return typeof entry === "string" ? entry : entry && typeof entry.source === "string" ? entry.source : null;
}

function packageKey(source) {
  if (!source.startsWith("npm:")) return source;
  const spec = source.slice(4);
  if (spec.startsWith("@")) {
    const slash = spec.indexOf("/");
    const version = slash >= 0 ? spec.indexOf("@", slash) : -1;
    return `npm:${version >= 0 ? spec.slice(0, version) : spec}`;
  }
  const version = spec.indexOf("@");
  return `npm:${version >= 0 ? spec.slice(0, version) : spec}`;
}

const emitted = new Set();
for (const entry of entries) {
  const source = sourceOf(entry);
  if (!source || desired.has(packageKey(source)) || emitted.has(source)) continue;
  emitted.add(source);
  process.stdout.write(`${source}\n`);
}
NODE
    [ -n "$package" ] || continue
    info "removing package outside the manifest: $package"
    "$pi_bin" remove "$package"
  done
fi

for package in $PACKAGES; do
  info "adding or updating $package to latest"
  "$pi_bin" install "$package"
done

if [ "$MODE" = 'sync' ]; then
  if [ "${PI_KIT_SKIP_PLAYWRIGHT_INSTALL:-0}" != '1' ]; then
    playwright_version=''
    playwright_bin=$(resolve_tool playwright)
    if [ -n "$playwright_bin" ]; then
      playwright_version=$("$playwright_bin" --version 2>/dev/null | awk '{print $2}')
    fi
    playwright_latest=$(npm view playwright version --registry "$NPM_REGISTRY" 2>/dev/null || true)
    if [ -z "$playwright_version" ] || { [ -n "$playwright_latest" ] && [ "$playwright_version" != "$playwright_latest" ]; }; then
      info 'installing or upgrading Playwright CLI (Chromium is installed on demand)'
      npm install --global --registry "$NPM_REGISTRY" "$PLAYWRIGHT_NPM_PACKAGE"
    else
      info "Playwright CLI $playwright_version is current"
    fi
    link_into_local_bin "$(resolve_tool playwright)" playwright
  fi

  skill_dir="$agent_dir/skills/playwright-cli"
  mkdir -p "$skill_dir"
  skill_tmp="$skill_dir/.SKILL.md.pi-kit.$$"
  cat >"$skill_tmp" <<'SKILL'
---
name: playwright-cli
description: Use Playwright from Bash or PowerShell for dynamic pages, screenshots, UI diagnosis, and existing end-to-end tests.
---

# Playwright CLI

Use this skill when a task needs a real browser, dynamic SPA interaction, screenshots, or end-to-end verification.

1. Prefer the repository's existing Playwright config and tests. Run the smallest relevant test first.
2. Use `npx playwright test <spec>` for repository tests and `npx playwright test --ui` only when a human will interact with the UI.
3. For one-off automation, create a temporary script outside the repository and run it with the installed `playwright` package. Do not add a dependency unless the project itself needs Playwright.
4. Install the browser binary on demand with `npx playwright install chromium`. Do not run `install-deps` or elevate privileges unless the user explicitly authorizes system changes.
5. Save requested screenshots and traces under the repository's existing artifact directory, or a temporary directory for diagnostics. Do not commit generated artifacts unless requested.
6. Never place credentials in scripts. Read them from existing environment variables and redact them from output.
SKILL
  mv -f "$skill_tmp" "$skill_dir/SKILL.md"

  # pi-kit <= 1.4.2 wrote this config for the retired pi-hashline-edit-pro
  # package. Remove it only while it still holds exactly what pi-kit wrote.
  xdg_config=${XDG_CONFIG_HOME:-"${HOME:?HOME is required}/.config"}
  hashline_dir="$xdg_config/pi-hashline-edit-pro"
  if [ -f "$hashline_dir/config.json" ] && node -e '
    const config = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    const keys = Object.keys(config).sort().join(",");
    if (keys !== "anchorGrepEnabled,autoRead" || config.autoRead !== true || config.anchorGrepEnabled !== false) process.exit(1);
  ' "$hashline_dir/config.json" 2>/dev/null; then
    rm -f "$hashline_dir/config.json"
    rmdir "$hashline_dir" 2>/dev/null || true
    info 'removed legacy pi-hashline-edit-pro config written by an older pi-kit'
  fi

  canonical_tmp="$agent_dir/.settings.canonical.pi-kit.$$"
  desired_tmp="$agent_dir/.settings.json.pi-kit.$$"
  cat >"$canonical_tmp" <<'JSON'
{
  "defaultThinkingLevel": "high",
  "compaction": {
    "enabled": true,
    "reserveTokens": 32768,
    "keepRecentTokens": 40000
  },
  "branchSummary": {
    "reserveTokens": 32768
  },
  "defaultTools": [
    "read",
    "bash",
    "edit",
    "write"
  ],
  "enableSkillCommands": true,
  "packages": [
    "npm:pi-semantic-edit",
    "npm:pi-web-access"
  ],
  "skills": [
    "skills/playwright-cli"
  ]
}
JSON

  # Machine-local choices survive sync: the selected default model is what
  # headless callers (for example `pi -p` delegation) run without --model.
  node - "$canonical_tmp" "$settings_file" "$desired_tmp" <<'NODE'
const { existsSync, readFileSync, writeFileSync } = require("node:fs");
const [canonicalFile, settingsFile, desiredFile] = process.argv.slice(2);
const PRESERVED_KEYS = ["defaultProvider", "defaultModel", "enabledModels", "theme", "lastChangelogVersion"];

// Key order is irrelevant to Pi, which may rewrite settings.json itself.
function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
  }
  return value;
}

const desired = JSON.parse(readFileSync(canonicalFile, "utf8"));
let existingText = null;
let existing = {};
if (existsSync(settingsFile)) {
  existingText = readFileSync(settingsFile, "utf8");
  try {
    existing = JSON.parse(existingText);
  } catch {
    existing = {};
    console.error("pi-kit: existing settings.json is not valid JSON; it will be backed up and replaced");
  }
}
if (existing && typeof existing === "object" && !Array.isArray(existing)) {
  for (const key of PRESERVED_KEYS) {
    if (Object.hasOwn(existing, key)) desired[key] = existing[key];
  }
}
const unchanged =
  existingText !== null && JSON.stringify(canonicalize(existing)) === JSON.stringify(canonicalize(desired));
writeFileSync(desiredFile, unchanged ? existingText : `${JSON.stringify(desired, null, 2)}\n`);
NODE
  rm -f "$canonical_tmp"

  if [ -f "$settings_file" ] && ! cmp -s "$settings_file" "$desired_tmp"; then
    backup_dir="$agent_dir/backups"
    mkdir -p "$backup_dir"
    backup_file="$backup_dir/settings.pre-pi-kit.$(date -u +%Y%m%dT%H%M%SZ).$$.json"
    cp "$settings_file" "$backup_file"
    chmod 600 "$backup_file" 2>/dev/null || true
    info "backed up previous settings to $backup_file"
  fi
  mv -f "$desired_tmp" "$settings_file"
  chmod 600 "$settings_file" 2>/dev/null || true
  info 'declarative settings synchronized; auth, models, and sessions were not accessed'
fi

info 'installed packages:'
"$pi_bin" list
