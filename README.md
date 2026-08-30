# pi-kit

A small Pi setup for coding work. Every run installs the current npm latest of:

- `pi-semantic-edit`
- `pi-web-access`
- `pi-subagents`

The installer is idempotent. Pi deduplicates packages by npm package name, so
rerunning it adds missing packages and updates existing ones without creating
duplicate entries. Other Pi packages, credentials, providers, models,
sessions, and project settings are left unchanged.

## Install

macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/zji996/pi-kit/v1.1.0/install.sh | sh
```

Windows PowerShell:

```powershell
irm 'https://raw.githubusercontent.com/zji996/pi-kit/v1.1.0/install.ps1' | iex
```

Requirements: internet access and Node.js `22.19.0` or newer. If Pi is not
installed, the bootstrap installs the latest `@earendil-works/pi-coding-agent`
with npm first. Existing compatible Pi installations are preserved.

The one-line commands use an immutable release tag. To review the Unix
installer first:

```sh
curl -fsSLO https://raw.githubusercontent.com/zji996/pi-kit/v1.1.0/install.sh
less install.sh
sh install.sh
```

## What changes

The bootstrap uses Pi's own package manager. The unversioned sources in
[`packages.list`](packages.list) resolve to npm latest each time. Existing
pinned entries for the same package are changed to unversioned entries in
place; Pi preserves their resource filters and all unrelated package entries.

It does not copy or publish anything from `~/.pi`, including `auth.json`, API
keys, custom providers, models, or session history.

## Update or remove

Rerun the same install command to update these three packages to their current
npm latest versions. It does not update or remove unrelated packages.

Remove individual packages with Pi:

```sh
pi remove npm:pi-semantic-edit
pi remove npm:pi-web-access
pi remove npm:pi-subagents
```

## Development

```sh
./scripts/check.sh
./scripts/test-install.sh
```

The install test redirects Pi to a temporary configuration directory and does
not touch the developer's regular Pi setup.

## 中文说明

这是一个公开的 Pi 插件追加/更新清单。每次运行都会把目标三个插件补齐并
更新到 npm latest；Pi 按包名自动去重，其他插件、API Key、模型配置和会话
保持不变。macOS/Linux 使用 `install.sh`，Windows 使用 `install.ps1`。

## License

MIT
