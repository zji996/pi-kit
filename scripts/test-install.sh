#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pi-kit-test.XXXXXX")

cleanup() {
  rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

PI_CODING_AGENT_DIR="$test_dir/agent" sh "$repo_dir/install.sh"

settings="$test_dir/agent/settings.json"
[ -f "$settings" ] || {
  printf '%s\n' 'pi-kit: isolated install did not create settings.json' >&2
  exit 1
}

node - "$settings" "$repo_dir/packages.lock" <<'NODE'
const { readFileSync } = require("node:fs");
const settings = JSON.parse(readFileSync(process.argv[2], "utf8"));
const expected = readFileSync(process.argv[3], "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#"));

if (JSON.stringify(settings.packages) !== JSON.stringify(expected)) {
  console.error("pi-kit: installed package list does not match packages.lock");
  console.error(JSON.stringify(settings.packages, null, 2));
  process.exit(1);
}
NODE

PI_CODING_AGENT_DIR="$test_dir/agent" sh "$repo_dir/install.sh" >/dev/null
printf '%s\n' 'pi-kit: isolated install and idempotency check passed'
