param(
    [switch]$Sync,
    [switch]$Additive
)

$ErrorActionPreference = "Stop"
$PiNpmName = "@earendil-works/pi-coding-agent"
$PiNpmPackage = "@earendil-works/pi-coding-agent@latest"
$MinimumPiVersion = [version]"0.84.4"
$Packages = @(
    "npm:pi-hashline-edit-pro",
    "npm:pi-web-access"
)
$Mode = if ($Additive) { "additive" } else { "sync" }

function Write-Info([string]$Message) {
    Write-Host "pi-kit: $Message"
}

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE"
    }
}

if ($Sync -and $Additive) {
    throw "-Sync and -Additive cannot be used together."
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 22.19.0 or newer is required."
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm is required."
}

$NodeVersion = [version]((& node --version).TrimStart("v"))
if ($NodeVersion -lt [version]"22.19.0") {
    throw "Node.js 22.19.0 or newer is required; found v$NodeVersion."
}

$PiCommand = Get-Command pi -ErrorAction SilentlyContinue
$InstalledVersion = if ($PiCommand) { [version]((& $PiCommand.Source --version).Trim()) } else { [version]"0.0.0" }
$LatestVersionText = (& npm view $PiNpmName version 2>$null)
$LatestVersion = if ($LASTEXITCODE -eq 0 -and $LatestVersionText) { [version]$LatestVersionText.Trim() } else { $null }

if (-not $PiCommand) {
    Write-Info "installing latest Pi"
    Invoke-Checked "npm" @("install", "--global", "--ignore-scripts", $PiNpmPackage)
} elseif ($InstalledVersion -lt $MinimumPiVersion -or ($LatestVersion -and $InstalledVersion -ne $LatestVersion)) {
    Write-Info "upgrading Pi from $InstalledVersion to latest"
    Invoke-Checked "npm" @("install", "--global", "--ignore-scripts", $PiNpmPackage)
} else {
    Write-Info "Pi $InstalledVersion is current"
}
$PiCommand = Get-Command pi -ErrorAction Stop

$AgentDir = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path $HOME ".pi/agent" }
$SettingsFile = Join-Path $AgentDir "settings.json"
New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null

function Get-PackageSource($Entry) {
    if ($Entry -is [string]) { return $Entry }
    if ($Entry -and $Entry.source -is [string]) { return $Entry.source }
    return $null
}

function Get-PackageKey([string]$Source) {
    if (-not $Source.StartsWith("npm:")) { return $Source }
    $Spec = $Source.Substring(4)
    if ($Spec.StartsWith("@")) {
        $Slash = $Spec.IndexOf("/")
        $Version = if ($Slash -ge 0) { $Spec.IndexOf("@", $Slash) } else { -1 }
        return "npm:" + $(if ($Version -ge 0) { $Spec.Substring(0, $Version) } else { $Spec })
    }
    $Version = $Spec.IndexOf("@")
    return "npm:" + $(if ($Version -ge 0) { $Spec.Substring(0, $Version) } else { $Spec })
}

if ($Mode -eq "sync" -and (Test-Path $SettingsFile)) {
    $Existing = Get-Content -Raw $SettingsFile | ConvertFrom-Json
    $DesiredKeys = @{}
    foreach ($Package in $Packages) { $DesiredKeys[(Get-PackageKey $Package)] = $true }
    foreach ($Entry in @($Existing.packages)) {
        $Source = Get-PackageSource $Entry
        if ($Source -and -not $DesiredKeys.ContainsKey((Get-PackageKey $Source))) {
            Write-Info "removing package outside the manifest: $Source"
            Invoke-Checked $PiCommand.Source @("remove", $Source)
        }
    }
}

foreach ($Package in $Packages) {
    Write-Info "adding or updating $Package to latest"
    Invoke-Checked $PiCommand.Source @("install", $Package)
}

if ($Mode -eq "sync") {
    if ($env:PI_KIT_SKIP_PLAYWRIGHT_INSTALL -ne "1") {
        $Playwright = Get-Command playwright -ErrorAction SilentlyContinue
        $PlaywrightVersion = if ($Playwright) { [version]((& $Playwright.Source --version).Trim().Split()[-1]) } else { $null }
        $LatestPlaywrightText = (& npm view playwright version 2>$null)
        $LatestPlaywrightVersion = if ($LASTEXITCODE -eq 0 -and $LatestPlaywrightText) { [version]$LatestPlaywrightText.Trim() } else { $null }
        if (-not $PlaywrightVersion -or ($LatestPlaywrightVersion -and $PlaywrightVersion -ne $LatestPlaywrightVersion)) {
            Write-Info "installing or upgrading Playwright CLI (Chromium is installed on demand)"
            Invoke-Checked "npm" @("install", "--global", "playwright@latest")
        } else {
            Write-Info "Playwright CLI $PlaywrightVersion is current"
        }
    }

    $SkillDir = Join-Path $AgentDir "skills/playwright-cli"
    New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
    $SkillText = @'
---
name: playwright-cli
description: Use Playwright from Bash or PowerShell for dynamic pages, screenshots, UI diagnosis, and existing end-to-end tests.
---

# Playwright CLI

Use this skill when a task needs a real browser, dynamic SPA interaction, screenshots, or end-to-end verification.

1. Prefer the repository's existing Playwright config and tests. Run the smallest relevant test first.
2. Use `npx playwright test <spec>` for repository tests and `npx playwright test --ui` only when a human will interact with the UI.
3. For one-off automation, create a temporary script outside the repository and run it with the installed `playwright` package. Do not add a dependency unless the project itself needs Playwright.
4. Install the browser binary on demand with `npx playwright install chromium`. Do not run `install-deps` or elevate privileges unless the user explicitly authorizes system changes.
5. Save requested screenshots and traces under the repository's existing artifact directory, or a temporary directory for diagnostics. Do not commit generated artifacts unless requested.
6. Never place credentials in scripts. Read them from existing environment variables and redact them from output.
'@
    $SkillFile = Join-Path $SkillDir "SKILL.md"
    [IO.File]::WriteAllText($SkillFile, $SkillText.Replace("`r`n", "`n") + "`n")

    $HashlineDir = Join-Path $HOME ".config/pi-hashline-edit-pro"
    New-Item -ItemType Directory -Force -Path $HashlineDir | Out-Null
    $HashlineConfig = [ordered]@{ autoRead = $true; anchorGrepEnabled = $false }
    [IO.File]::WriteAllText((Join-Path $HashlineDir "config.json"), ($HashlineConfig | ConvertTo-Json) + "`n")

    $DesiredSettings = [ordered]@{
        defaultThinkingLevel = "high"
        compaction = [ordered]@{ enabled = $true; reserveTokens = 32768; keepRecentTokens = 40000 }
        branchSummary = [ordered]@{ reserveTokens = 32768 }
        defaultTools = @("read", "powershell", "edit", "write")
        enableSkillCommands = $true
        packages = $Packages
        skills = @("skills/playwright-cli")
    }
    $DesiredText = ($DesiredSettings | ConvertTo-Json -Depth 10) + "`n"
    if (Test-Path $SettingsFile) {
        $ExistingText = [IO.File]::ReadAllText($SettingsFile)
        if ($ExistingText -ne $DesiredText) {
            $BackupDir = Join-Path $AgentDir "backups"
            New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
            $Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
            $BackupFile = Join-Path $BackupDir "settings.pre-pi-kit.$Stamp.$PID.json"
            Copy-Item $SettingsFile $BackupFile
            Write-Info "backed up previous settings to $BackupFile"
        }
    }
    $SettingsTemp = Join-Path $AgentDir ".settings.json.pi-kit.$PID"
    [IO.File]::WriteAllText($SettingsTemp, $DesiredText)
    Move-Item -Force $SettingsTemp $SettingsFile
    Write-Info "declarative settings synchronized; auth, models, and sessions were not accessed"
}

Write-Info "installed packages:"
Invoke-Checked $PiCommand.Source @("list")
