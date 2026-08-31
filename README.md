# pi-kit

A curated Pi setup for coding work. Every run installs the current npm latest of:

- `pi-hashline-edit-pro` (Line-hash precise editing, highly resilient to context drift)
- `pi-web-access` (Web search & URL fetching)

The installer is idempotent. Pi deduplicates packages by npm package name, so
rerunning it adds missing packages and updates existing ones without creating
duplicate entries. Other Pi packages, credentials, providers, models,
sessions, and project settings are left unchanged.

## Install

### Option A: Via Self-Hosted Git (192.168.8.6 / Forgejo)

macOS or Linux:

```sh
curl -fsSL https://git.aiatechco.com/zji996/pi-kit/raw/branch/main/install.sh | sh
```

Windows PowerShell:

```powershell
irm 'https://git.aiatechco.com/zji996/pi-kit/raw/branch/main/install.ps1' | iex
```

### Option B: Via GitHub

macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/zji996/pi-kit/v1.3.0/install.sh | sh
```

Windows PowerShell:

```powershell
irm 'https://raw.githubusercontent.com/zji996/pi-kit/v1.3.0/install.ps1' | iex
```

### Option C: Git Clone

```sh
git clone ssh://git@git.aiatechco.com:30222/zji996/pi-kit.git
cd pi-kit && sh install.sh
```

Requirements: internet access and Node.js `22.19.0` or newer. If Pi is not
installed, the bootstrap installs the latest `@earendil-works/pi-coding-agent`
with npm first. Existing compatible Pi installations are preserved.

## Best Practices & Context Budget Guide

For in-depth guidance on context budgeting, Low-Thinking summarization strategies, and maximizing Prompt Cache hits in long sessions, see [`docs/context-budget-guide.md`](docs/context-budget-guide.md).

## What changes

The bootstrap uses Pi's own package manager. The unversioned sources in
[`packages.list`](packages.list) resolve to npm latest each time. Existing
pinned entries for the same package are changed to unversioned entries in
place; Pi preserves their resource filters and all unrelated package entries.

It does not copy or publish anything from `~/.pi`, including `auth.json`, API
keys, custom providers, models, or session history.

## Update or remove

Rerun the same install command to update the packages to their current npm latest versions.

Remove individual packages with Pi:

```sh
pi remove npm:pi-hashline-edit-pro
pi remove npm:pi-web-access
```

## Development

```sh
./scripts/check.sh
./scripts/test-install.sh
```

The install test redirects Pi to a temporary configuration directory and does
not touch the developer's regular Pi setup.

## 中文说明

这是一个公开的 Pi 插件追加/更新清单与最佳实践配置库。每次运行都会把目标插件（`pi-hashline-edit-pro` 和 `pi-web-access`）补齐并更新到 npm latest；Pi 按包名自动去重，其他插件、API Key、模型配置和会话保持不变。

详细的长会话上下文预算与 Low-Thinking 思考等级调优指南见 [`docs/context-budget-guide.md`](docs/context-budget-guide.md)。

## License

MIT
