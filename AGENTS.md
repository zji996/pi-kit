# AGENTS.md

`pi-kit` is a public, non-secret bootstrap and declarative configuration repository for Pi.

## Constraints

- Keep `packages.list`, both canonical settings files, `install.sh`, and `install.ps1` in sync.
- Keep listed Pi package sources unversioned so every run resolves npm latest.
- Release tags pin installer behavior, not the versions of listed Pi packages.
- Never add Pi credentials, provider keys, model configuration, sessions, or a copy of `~/.pi`.
- The default mode is declarative sync. It may replace `settings.json`, remove packages outside `packages.list`, and replace the managed Playwright skill.
- Before replacing a non-canonical `settings.json`, save a local backup under the Pi agent directory.
- Sync preserves the machine-local keys `defaultProvider`, `defaultModel`, `enabledModels`, `theme`, and `lastChangelogVersion`; keep that list identical in both installers and `scripts/check.mjs`. Key order and formatting alone are not drift.
- Never read, copy, remove, or overwrite `auth.json`, `models.json`, `models-store.json`, `sessions/`, or project-local Pi data.
- Use Pi's package commands to install and uninstall packages; do not remove package directories directly.
- Keep `--additive` as the explicitly non-destructive compatibility mode.
- Support macOS and Linux in `install.sh`, and Windows in `install.ps1`.

## Validation

```sh
./scripts/check.sh
./scripts/test-install.sh
```

The install test uses `PI_CODING_AGENT_DIR` and `XDG_CONFIG_HOME` with a temporary directory. It must not touch the caller's normal Pi configuration.
