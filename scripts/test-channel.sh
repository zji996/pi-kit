#!/bin/sh
# Channel switching against a fake Node Pi package and a local rpi archive:
# no network, and nothing outside a temporary HOME and npm prefix is touched.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pi-kit-channel.XXXXXX")
cleanup() {
  rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

check() {
  if ! eval "$1"; then
    printf '%s\n' "pi-kit: channel test failed: $2" >&2
    exit 1
  fi
}

prefix="$test_dir/prefix"
package="$prefix/lib/node_modules/@earendil-works/pi-coding-agent"
mkdir -p "$package/dist/bundle" "$prefix/bin" "$test_dir/home/.local/bin" "$test_dir/build"
printf '%s\n' '{"name":"@earendil-works/pi-coding-agent","bin":{"pi":"dist/bundle/cli.js"}}' >"$package/package.json"
printf '%s\n' '#!/bin/sh' 'echo node-pi' >"$package/dist/bundle/cli.js"
chmod 755 "$package/dist/bundle/cli.js"
ln -s ../lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js "$prefix/bin/pi"

printf '%s\n' '#!/bin/sh' 'echo rpi' >"$test_dir/build/rpi"
chmod 755 "$test_dir/build/rpi"
archive="$test_dir/rpi.tar.gz"
tar -czf "$archive" -C "$test_dir/build" rpi
if command -v sha256sum >/dev/null 2>&1; then
  digest=$(sha256sum "$archive" | awk '{print $1}')
else
  digest=$(shasum -a 256 "$archive" | awk '{print $1}')
fi

agent="$test_dir/home/.pi/agent"
mkdir -p "$agent/skills/demo"
printf '%s\n' '{"token":"local-only"}' >"$agent/auth.json"
printf '%s\n' '{"providers":{}}' >"$agent/models.json"
printf '%s\n' '{"defaultProvider":"local-provider","defaultModel":"local-model","theme":"dark"}' >"$agent/settings.json"
cp "$agent/auth.json" "$test_dir/auth.before"

export HOME="$test_dir/home" npm_config_prefix="$prefix" XDG_CONFIG_HOME="$test_dir/xdg"
export PI_CODING_AGENT_DIR="$agent" NPM_REGISTRY='https://registry.npmjs.org'
export PATH="$prefix/bin:$HOME/.local/bin:$PATH" PI_KIT_RPI_ARCHIVE="$archive"
unset RPI_CODING_AGENT_DIR

if PI_KIT_RPI_SHA256=0000 sh "$repo_dir/install.sh" --channel rpi >/dev/null 2>&1; then
  check false 'an archive with the wrong digest was accepted'
fi
check '[ ! -e "$HOME/.local/lib/rpi" ]' 'a rejected archive was installed'

PI_KIT_RPI_SHA256=$digest sh "$repo_dir/install.sh" --channel rpi >/dev/null
check '[ "$(pi)" = rpi ]' 'pi on PATH does not run rpi'
check '[ "$("$prefix/bin/pi")" = rpi ]' 'the npm bin link still runs Node Pi'
check '[ "$(pi-node)" = node-pi ]' 'pi-node does not reach Node Pi'
check '[ "$(cat "$XDG_CONFIG_HOME/pi-kit/channel")" = rpi ]' 'the channel was not recorded'
for name in auth.json models.json skills; do
  check '[ "$(readlink "$HOME/.rpi/agent/$name")" = "$agent/$name" ]' "rpi does not share $name through a link"
done
cmp -s "$agent/auth.json" "$test_dir/auth.before" || check false 'auth.json changed'
node - "$HOME/.rpi/agent/settings.json" <<'NODE'
const settings = JSON.parse(require("node:fs").readFileSync(process.argv[2], "utf8"));
if (settings.defaultModel !== "local-model" || settings.defaultProvider !== "local-provider") {
  throw new Error(`rpi settings lost the model choice: ${JSON.stringify(settings)}`);
}
if (settings.defaultThinkingLevel !== "high" || settings.theme !== undefined) {
  throw new Error(`rpi settings are not canonical: ${JSON.stringify(settings)}`);
}
NODE

sh "$repo_dir/install.sh" --channel pi >/dev/null
check '[ "$(pi)" = node-pi ]' 'pi on PATH does not run Node Pi after switching back'
check '[ ! -e "$HOME/.local/bin/pi-node" ]' 'pi-node outlived the rpi channel'
check '[ "$(cat "$XDG_CONFIG_HOME/pi-kit/channel")" = pi ]' 'the pi channel was not recorded'

printf '%s\n' 'pi-kit: channel switch, digest pinning, and shared-state links passed'
