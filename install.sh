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

usage() {
  printf '%s\n' 'Usage: install.sh [--sync|--additive]'
  printf '%s\n' '  --sync      replace settings and remove packages outside packages.list (default)'
  printf '%s\n' '  --additive  only add or update packages; preserve all existing settings'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sync) MODE='sync' ;;
    --additive) MODE='additive' ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

command -v node >/dev/null 2>&1 || fail 'Node.js 22.19.0 or newer is required.'
command -v npm >/dev/null 2>&1 || fail 'npm is required.'

node -e '
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 22 || (major === 22 && minor < 19)) process.exit(1);
' || fail "Node.js 22.19.0 or newer is required; found $(node --version)."

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

latest_version=$(npm view "$PI_NPM_NAME" version 2>/dev/null || true)
if [ -z "$pi_bin" ]; then
  info 'installing latest Pi'
  npm install --global --ignore-scripts "$PI_NPM_PACKAGE"
elif ! version_at_least "$installed_version" "$MINIMUM_PI_VERSION"; then
  info "upgrading Pi from $installed_version to latest"
  npm install --global --ignore-scripts "$PI_NPM_PACKAGE"
elif [ -n "$latest_version" ] && [ "$installed_version" != "$latest_version" ]; then
  info "upgrading Pi from $installed_version to $latest_version"
  npm install --global --ignore-scripts "$PI_NPM_PACKAGE"
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

agent_dir=${PI_CODING_AGENT_DIR:-"${HOME:?HOME is required}/.pi/agent"}
settings_file="$agent_dir/settings.json"
mkdir -p "$agent_dir"

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
    if command -v playwright >/dev/null 2>&1; then
      info "Playwright CLI available: $(playwright --version)"
    else
      info 'installing Playwright CLI (Chromium is installed on demand)'
      npm install --global "$PLAYWRIGHT_NPM_PACKAGE"
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
