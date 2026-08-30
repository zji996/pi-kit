# pi-kit

A small, version-pinned Pi setup for coding work. It installs:

- `pi-semantic-edit` `0.4.0`
- `pi-web-access` `0.27.0`
- `pi-subagents` `0.60.0`

The installer is idempotent. It adds or updates only these packages and leaves
other Pi packages, credentials, providers, models, sessions, and project
settings unchanged.

## Install

macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/zji996/pi-kit/v1.0.1/install.sh | sh
```

Windows PowerShell:

```powershell
irm 'https://raw.githubusercontent.com/zji996/pi-kit/v1.0.1/install.ps1' | iex
```

Requirements: internet access and Node.js `22.19.0` or newer. If Pi is not
installed, the bootstrap installs `@earendil-works/pi-coding-agent@0.84.4`
with npm first. Existing newer Pi versions are preserved.

The one-line commands use an immutable release tag. To review the Unix
installer first:

```sh
curl -fsSLO https://raw.githubusercontent.com/zji996/pi-kit/v1.0.1/install.sh
less install.sh
sh install.sh
```

## What changes

The bootstrap uses Pi's own package manager. The resulting package entries are
stored in the normal Pi settings directory and pinned to the versions in
[`packages.lock`](packages.lock). Running the installer again is safe and
reconciles the same package identities.

It does not copy or publish anything from `~/.pi`, including `auth.json`, API
keys, custom providers, models, or session history.

## Upgrade or remove

Upgrades are explicit: review a newer repository revision, then rerun its
installer. Pinned packages are intentionally skipped by ordinary
`pi update --extensions` runs.

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

这是一个公开、版本锁定的 Pi 插件安装清单。已有 Pi 或已经装过其中
部分插件都可以重复运行安装命令；脚本不会读取或覆盖 API Key、模型配置、
会话与其他插件。macOS/Linux 使用 `install.sh`，Windows 使用
`install.ps1`。

## License

MIT
