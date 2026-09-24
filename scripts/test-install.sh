#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pi-kit-test.XXXXXX")

cleanup() {
  rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

agent_dir="$test_dir/agent"
mkdir -p "$agent_dir/sessions/project" "$agent_dir/npm/node_modules/pi-subagents" "$test_dir/xdg"
export PI_CODING_AGENT_DIR="$agent_dir"
export XDG_CONFIG_HOME="$test_dir/xdg"
export PI_KIT_SKIP_PLAYWRIGHT_INSTALL=1

node - "$agent_dir" <<'NODE'
const { mkdirSync, writeFileSync } = require("node:fs");
const { join } = require("node:path");
const agent = process.argv[2];

const settings = {
  defaultProvider: "local-provider",
  defaultModel: "local-model",
  theme: "local-theme",
  defaultThinkingLevel: "low",
  defaultTools: ["read", "grep"],
  compaction: { reserveTokens: 1, keepRecentTokens: 2 },
  packages: [
    "npm:pi-subagents@0.60.0",
    { source: "npm:pi-hashline-edit-pro@2.8.0", extensions: ["index.ts"] },
    "npm:pi-web-access@0.26.0",
  ],
};
writeFileSync(join(agent, "settings.json"), `${JSON.stringify(settings, null, 2)}\n`);
writeFileSync(join(agent, "auth.json"), '{"token":"local-only"}\n');
writeFileSync(join(agent, "models.json"), '{"models":["local"]}\n');
writeFileSync(join(agent, "models-store.json"), '{"cache":"local"}\n');
writeFileSync(join(agent, "sessions/project/session.jsonl"), '{"message":"local session"}\n');
writeFileSync(join(agent, "npm/package.json"), '{"private":true,"dependencies":{"pi-subagents":"0.60.0"}}\n');
mkdirSync(join(agent, "npm/node_modules/pi-subagents"), { recursive: true });
writeFileSync(join(agent, "npm/node_modules/pi-subagents/package.json"), '{"name":"pi-subagents","version":"0.60.0"}\n');
NODE

# Legacy config written by pi-kit <= 1.4.2 for the retired hashline package.
mkdir -p "$test_dir/xdg/pi-hashline-edit-pro"
printf '%s\n' '{' '  "autoRead": true,' '  "anchorGrepEnabled": false' '}' >"$test_dir/xdg/pi-hashline-edit-pro/config.json"

mkdir -p "$test_dir/protected"
cp "$agent_dir/auth.json" "$test_dir/protected/auth.json"
cp "$agent_dir/models.json" "$test_dir/protected/models.json"
cp "$agent_dir/models-store.json" "$test_dir/protected/models-store.json"
cp "$agent_dir/sessions/project/session.jsonl" "$test_dir/protected/session.jsonl"

sh "$repo_dir/install.sh" --sync

node - "$agent_dir" "$repo_dir/settings.unix.json" <<'NODE'
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const agent = process.argv[2];
const expected = {
  ...JSON.parse(readFileSync(process.argv[3], "utf8")),
  defaultProvider: "local-provider",
  defaultModel: "local-model",
  theme: "local-theme",
};
const actual = JSON.parse(readFileSync(join(agent, "settings.json"), "utf8"));
if (JSON.stringify(actual) !== JSON.stringify(expected)) {
  throw new Error(`settings did not converge to canonical state plus local keys: ${JSON.stringify(actual)}`);
}

const dependencies = Object.keys(JSON.parse(readFileSync(join(agent, "npm/package.json"), "utf8")).dependencies ?? {}).sort();
const expectedDependencies = ["pi-semantic-edit", "pi-web-access"];
if (JSON.stringify(dependencies) !== JSON.stringify(expectedDependencies)) {
  throw new Error(`unexpected direct dependencies: ${dependencies.join(", ")}`);
}
NODE

cmp "$agent_dir/auth.json" "$test_dir/protected/auth.json"
cmp "$agent_dir/models.json" "$test_dir/protected/models.json"
cmp "$agent_dir/models-store.json" "$test_dir/protected/models-store.json"
cmp "$agent_dir/sessions/project/session.jsonl" "$test_dir/protected/session.jsonl"
cmp "$agent_dir/skills/playwright-cli/SKILL.md" "$repo_dir/skills/playwright-cli/SKILL.md"
[ ! -e "$XDG_CONFIG_HOME/pi-hashline-edit-pro" ] || {
  printf '%s\n' 'pi-kit: legacy pi-hashline-edit-pro config was not removed' >&2
  exit 1
}
[ ! -e "$agent_dir/npm/node_modules/pi-subagents" ] || {
  printf '%s\n' 'pi-kit: stale pi-subagents directory was not uninstalled' >&2
  exit 1
}

backup_count=$(find "$agent_dir/backups" -type f -name 'settings.pre-pi-kit.*.json' | wc -l)
[ "$backup_count" -eq 1 ] || {
  printf '%s\n' "pi-kit: expected one settings backup, found $backup_count" >&2
  exit 1
}

# Pi may rewrite settings.json with its own key order and new local keys;
# that must not count as drift or trigger another backup.
node - "$agent_dir/settings.json" <<'NODE'
const { readFileSync, writeFileSync } = require("node:fs");
const file = process.argv[2];
const settings = JSON.parse(readFileSync(file, "utf8"));
settings.lastChangelogVersion = "9.9.9";
const reordered = Object.fromEntries(Object.entries(settings).reverse());
writeFileSync(file, `${JSON.stringify(reordered)}\n`);
NODE
cp "$agent_dir/settings.json" "$test_dir/settings.after-first.json"
sh "$repo_dir/install.sh" --sync >/dev/null
cmp "$agent_dir/settings.json" "$test_dir/settings.after-first.json"
backup_count_after=$(find "$agent_dir/backups" -type f -name 'settings.pre-pi-kit.*.json' | wc -l)
[ "$backup_count_after" -eq "$backup_count" ] || {
  printf '%s\n' 'pi-kit: idempotent sync created another settings backup' >&2
  exit 1
}

list_output=$(pi list)
printf '%s\n' "$list_output" | grep -q 'npm:pi-semantic-edit'
printf '%s\n' "$list_output" | grep -q 'npm:pi-web-access'
if printf '%s\n' "$list_output" | grep -q 'pi-subagents'; then
  printf '%s\n' 'pi-kit: pi-subagents remains in pi list' >&2
  exit 1
fi

printf '%s\n' 'pi-kit: clean sync, private-state protection, and idempotency checks passed'
