#!/bin/sh
set -eu

PI_NPM_NAME='@earendil-works/pi-coding-agent'
PI_NPM_PACKAGE="$PI_NPM_NAME@latest"
MINIMUM_PI_VERSION='0.84.4'
PLAYWRIGHT_NPM_PACKAGE='playwright@latest'
PACKAGES='
npm:pi-hashline-edit-pro
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
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

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

    # Persist PATH in shell configuration if not already configured
    for rc_file in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.zshrc"; do
      if [ -f "$rc_file" ] && ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc_file"
      fi
    done

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

pi_bin=''
installed_version='0.0.0'
if command -v pi >/dev/null 2>&1; then
  pi_bin=$(command -v pi)
  installed_version=$($pi_bin --version 2>/dev/null || printf '0.0.0')
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

pi_bin=$(command -v pi 2>/dev/null || true)
if [ -z "$pi_bin" ]; then
  npm_prefix=$(npm prefix --global)
  candidate="$npm_prefix/bin/pi"
  [ -x "$candidate" ] || fail 'Pi was installed, but its executable is not on PATH.'
  pi_bin=$candidate
fi

# Ensure pi is always accessible directly from ~/.local/bin without self-referential symlink
if [ -n "$pi_bin" ] && [ "$pi_bin" != "${HOME}/.local/bin/pi" ]; then
  ln -sf "$pi_bin" "${HOME}/.local/bin/pi" 2>/dev/null || true
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

const desired = new Set(["npm:pi-hashline-edit-pro", "npm:pi-web-access"]);
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
    if command -v playwright >/dev/null 2>&1; then
      playwright_version=$(playwright --version 2>/dev/null | awk '{print $2}')
    fi
    playwright_latest=$(npm view playwright version --registry "$NPM_REGISTRY" 2>/dev/null || true)
    if [ -z "$playwright_version" ] || { [ -n "$playwright_latest" ] && [ "$playwright_version" != "$playwright_latest" ]; }; then
      info 'installing or upgrading Playwright CLI (Chromium is installed on demand)'
      npm install --global --registry "$NPM_REGISTRY" "$PLAYWRIGHT_NPM_PACKAGE"
    else
      info "Playwright CLI $playwright_version is current"
    fi
    playwright_bin=$(command -v playwright 2>/dev/null || true)
    if [ -n "$playwright_bin" ] && [ "$playwright_bin" != "${HOME}/.local/bin/playwright" ]; then
      ln -sf "$playwright_bin" "${HOME}/.local/bin/playwright" 2>/dev/null || true
    fi
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

  xdg_config=${XDG_CONFIG_HOME:-"${HOME:?HOME is required}/.config"}
  hashline_dir="$xdg_config/pi-hashline-edit-pro"
  mkdir -p "$hashline_dir"
  hashline_tmp="$hashline_dir/.config.json.pi-kit.$$"
  cat >"$hashline_tmp" <<'JSON'
{
  "autoRead": true,
  "anchorGrepEnabled": false
}
JSON
  mv -f "$hashline_tmp" "$hashline_dir/config.json"

  desired_tmp="$agent_dir/.settings.json.pi-kit.$$"
  cat >"$desired_tmp" <<'JSON'
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
    "npm:pi-hashline-edit-pro",
    "npm:pi-web-access"
  ],
  "skills": [
    "skills/playwright-cli"
  ]
}
JSON

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
