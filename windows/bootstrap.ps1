#Requires -RunAsAdministrator

param(
    [ValidateSet('Home', 'Work')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$wslBootstrap = Join-Path $PSScriptRoot 'bootstrap-wsl.ps1'
$linuxBootstrap = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\bootstrap-home.sh'

if (-not $PSBoundParameters.ContainsKey('Profile')) {
    do {
        $selection = (Read-Host 'Select an application profile (Home or Work)').Trim()
        $Profile = switch -Regex ($selection) {
            '^(?i:home|h)$' { 'Home'; break }
            '^(?i:work|w)$' { 'Work'; break }
            default { Write-Warning "Unknown profile '$selection'. Enter Home or Work." }
        }
    } until ($Profile)
}

$configurationFiles = @(
    (Join-Path $PSScriptRoot 'configuration.winget')
    (Join-Path $PSScriptRoot 'packages-common.winget')
    (Join-Path $PSScriptRoot "packages-$($Profile.ToLowerInvariant()).winget")
)

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store, then rerun this script.'
}

function Invoke-WinGet {
    param([string[]]$Arguments)
    & winget.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

Invoke-WinGet -Arguments @('configure', '--enable')
Write-Host "Using application profile: $Profile"
foreach ($configuration in $configurationFiles) {
    if (-not (Test-Path $configuration -PathType Leaf)) {
        throw "WinGet configuration is missing: $configuration"
    }
    Write-Host "Validating $(Split-Path $configuration -Leaf)..."
    Invoke-WinGet -Arguments @('configure', 'validate', '-f', $configuration)
}
foreach ($configuration in $configurationFiles) {
    Write-Host "Applying $(Split-Path $configuration -Leaf)..."
    Invoke-WinGet -Arguments @('configure', '-f', $configuration,
        '--accept-configuration-agreements', '--disable-interactivity')
}

& $wslBootstrap
if ($LASTEXITCODE -eq 10) {
    Write-Host 'WSL was just installed. Reboot if requested, launch Ubuntu to create the Linux user, then rerun this bootstrap.'
    exit 0
}
if ($LASTEXITCODE -ne 0) {
    throw "WSL bootstrap failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $linuxBootstrap)) {
    throw "Linux bootstrap is missing: $linuxBootstrap"
}

# Run the checked-out Linux bootstrap from its WSL-mounted path. It installs
# Linux Git and clones the repository inside Ubuntu; no native Git is required.
$wslPath = (& wsl.exe -d Ubuntu -- wslpath -a -u $linuxBootstrap).Trim()
if ($LASTEXITCODE -ne 0 -or -not $wslPath) {
    throw 'Ubuntu is not ready. Launch it once to create the Linux user, then rerun this bootstrap.'
}
Write-Host 'Bootstrapping Nix and Home Manager inside Ubuntu...'
& wsl.exe -d Ubuntu -- bash $wslPath
if ($LASTEXITCODE -ne 0) {
    throw "Linux bootstrap failed with exit code $LASTEXITCODE. Correct the reported issue and rerun this script."
}

foreach ($configuration in $configurationFiles) {
    Write-Host "Testing $(Split-Path $configuration -Leaf)..."
    Invoke-WinGet -Arguments @('configure', 'test', '-f', $configuration)
}
Write-Host 'Windows and WSL bootstrap complete. No reboot was performed automatically.'
