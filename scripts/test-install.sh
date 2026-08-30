#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pi-kit-test.XXXXXX")

cleanup() {
  rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$test_dir/agent"
export PI_CODING_AGENT_DIR="$test_dir/agent"
node - "$test_dir/agent/settings.json" <<'NODE'
const { writeFileSync } = require("node:fs");

const settings = {
  packages: [
    "npm:existing-plugin@1.2.3",
    "npm:pi-subagents@0.60.0",
    {
      source: "npm:pi-semantic-edit@0.3.0",
      extensions: ["index.ts"],
    },
    "npm:pi-web-access@0.26.0",
  ],
};

writeFileSync(process.argv[2], `${JSON.stringify(settings, null, 2)}\n`);
NODE

sh "$repo_dir/install.sh"

settings="$test_dir/agent/settings.json"
[ -f "$settings" ] || {
  printf '%s\n' 'pi-kit: isolated install did not create settings.json' >&2
  exit 1
}

node - "$settings" "$repo_dir/packages.list" <<'NODE'
const { readFileSync } = require("node:fs");
const { execFileSync } = require("node:child_process");
const settings = JSON.parse(readFileSync(process.argv[2], "utf8"));
const expected = readFileSync(process.argv[3], "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#"));

for (const source of expected) {
  const matches = settings.packages.filter((entry) =>
    (typeof entry === "string" ? entry : entry.source) === source,
  );
  if (matches.length !== 1) {
    throw new Error(`${source} appears ${matches.length} times in settings`);
  }

  const name = source.slice("npm:".length);
  const installed = JSON.parse(
    readFileSync(`${process.env.PI_CODING_AGENT_DIR}/npm/node_modules/${name}/package.json`, "utf8"),
  ).version;
  const latest = JSON.parse(
    execFileSync("npm", ["view", name, "dist-tags.latest", "--json"], { encoding: "utf8" }),
  );
  if (installed !== latest) {
    throw new Error(`${name}: installed ${installed}, npm latest is ${latest}`);
  }
}

if (!settings.packages.includes("npm:existing-plugin@1.2.3")) {
  throw new Error("unrelated existing package was changed or removed");
}

if (!settings.packages.includes("npm:pi-subagents@0.60.0")) {
  throw new Error("previously installed pi-subagents should not be removed implicitly");
}

const semantic = settings.packages.find(
  (entry) => typeof entry === "object" && entry.source === "npm:pi-semantic-edit",
);
if (!semantic || JSON.stringify(semantic.extensions) !== JSON.stringify(["index.ts"])) {
  throw new Error("existing package filters were not preserved");
}
NODE

cp "$settings" "$test_dir/settings.after-first.json"
sh "$repo_dir/install.sh" >/dev/null
cmp "$settings" "$test_dir/settings.after-first.json"
printf '%s\n' 'pi-kit: latest, preservation, deduplication, and idempotency checks passed'
