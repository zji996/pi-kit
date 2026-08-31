#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$repo_dir/install.sh"
sh -n "$repo_dir/sync.sh"
node "$repo_dir/scripts/check.mjs"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw '$repo_dir/install.ps1'))"
else
  printf '%s\n' 'pi-kit: pwsh not found; skipped PowerShell syntax check'
fi
