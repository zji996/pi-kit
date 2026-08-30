#!/bin/sh
set -eu

PI_NPM_PACKAGE='@earendil-works/pi-coding-agent@latest'
MINIMUM_PI_VERSION='0.84.4'
PACKAGES='
npm:pi-semantic-edit
npm:pi-web-access
'

info() {
  printf '%s\n' "pi-kit: $*"
}

fail() {
  printf '%s\n' "pi-kit: error: $*" >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail 'Node.js 22.19.0 or newer is required.'
command -v npm >/dev/null 2>&1 || fail 'npm is required.'

node -e '
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 22 || (major === 22 && minor < 19)) process.exit(1);
' || fail "Node.js 22.19.0 or newer is required; found $(node --version)."

pi_bin=''
if command -v pi >/dev/null 2>&1; then
  pi_bin=$(command -v pi)
  installed_version=$("$pi_bin" --version 2>/dev/null || printf '0.0.0')
  if ! node -e '
    const current = process.argv[1].split(".").map(Number);
    const minimum = process.argv[2].split(".").map(Number);
    for (let i = 0; i < 3; i += 1) {
      if ((current[i] || 0) > (minimum[i] || 0)) process.exit(0);
      if ((current[i] || 0) < (minimum[i] || 0)) process.exit(1);
    }
  ' "$installed_version" "$MINIMUM_PI_VERSION"; then
    info "upgrading Pi from $installed_version to latest"
    npm install --global "$PI_NPM_PACKAGE"
    pi_bin=$(command -v pi 2>/dev/null || true)
  fi
else
  info 'installing latest Pi'
  npm install --global "$PI_NPM_PACKAGE"
  pi_bin=$(command -v pi 2>/dev/null || true)
fi

if [ -z "$pi_bin" ]; then
  npm_prefix=$(npm prefix --global)
  candidate="$npm_prefix/bin/pi"
  [ -x "$candidate" ] || fail 'Pi was installed, but its executable is not on PATH.'
  pi_bin=$candidate
fi

for package in $PACKAGES; do
  info "adding or updating $package to latest"
  "$pi_bin" install "$package"
done

info 'installed packages:'
"$pi_bin" list
