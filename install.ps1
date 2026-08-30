$ErrorActionPreference = "Stop"

$PiNpmPackage = "@earendil-works/pi-coding-agent@latest"
$MinimumPiVersion = [version]"0.84.4"
$Packages = @(
    "npm:pi-semantic-edit",
    "npm:pi-web-access"
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
        Write-Info "upgrading Pi from $InstalledVersion to latest"
        & npm install --global $PiNpmPackage
        $PiCommand = Get-Command pi -ErrorAction Stop
    }
} else {
    Write-Info "installing latest Pi"
    & npm install --global $PiNpmPackage
    $PiCommand = Get-Command pi -ErrorAction Stop
}

foreach ($Package in $Packages) {
    Write-Info "adding or updating $Package to latest"
    & $PiCommand.Source install $Package
}

Write-Info "installed packages:"
& $PiCommand.Source list
