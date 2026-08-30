$ErrorActionPreference = "Stop"

$PiNpmPackage = "@earendil-works/pi-coding-agent@0.84.4"
$MinimumPiVersion = [version]"0.84.4"
$Packages = @(
    "npm:pi-semantic-edit@0.4.0",
    "npm:pi-web-access@0.27.0",
    "npm:pi-subagents@0.60.0"
)

function Write-Info([string]$Message) {
    Write-Host "pi-kit: $Message"
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
if ($PiCommand) {
    $InstalledVersion = [version]((& $PiCommand.Source --version).Trim())
    if ($InstalledVersion -lt $MinimumPiVersion) {
        Write-Info "upgrading Pi from $InstalledVersion to $MinimumPiVersion"
        & npm install --global $PiNpmPackage
        $PiCommand = Get-Command pi -ErrorAction Stop
    }
} else {
    Write-Info "installing Pi $MinimumPiVersion"
    & npm install --global $PiNpmPackage
    $PiCommand = Get-Command pi -ErrorAction Stop
}

foreach ($Package in $Packages) {
    Write-Info "installing $Package"
    & $PiCommand.Source install $Package
}

Write-Info "installed packages:"
& $PiCommand.Source list
