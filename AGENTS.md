# AGENTS.md

`pi-kit` is a public, non-secret bootstrap repository for a small set of Pi
packages.

## Constraints

- Keep `packages.list`, `install.sh`, and `install.ps1` in sync.
- Keep listed Pi package sources unversioned so every run resolves npm latest.
- Release tags pin installer behavior, not the versions of listed Pi packages.
- Never add Pi credentials, provider keys, model configuration, sessions, or a
  copy of `~/.pi`.
- Install packages through `pi install`; do not edit Pi settings directly.
- Keep installers idempotent and non-destructive. They may add or update the
  packages listed here, but must not remove unrelated packages.
- Support macOS and Linux in `install.sh`, and Windows in `install.ps1`.

## Validation

```sh
./scripts/check.sh
./scripts/test-install.sh
```

The install test uses `PI_CODING_AGENT_DIR` with a temporary directory and
must not touch the caller's normal Pi configuration.
