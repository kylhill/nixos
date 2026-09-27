#Requires -RunAsAdministrator

param(
    [string]$Distro = 'Ubuntu'
)

$ErrorActionPreference = 'Stop'
$failures = @()

function Invoke-UpdateStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Host "Updating $Name..."
    try {
        & $Action
        if ($LASTEXITCODE -ne 0) {
            throw "$Name update failed with exit code $LASTEXITCODE."
        }
    } catch {
        Write-Error $_ -ErrorAction Continue
        $script:failures += $Name
    }
}

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store, then rerun this script.'
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL is required.'
}

$installedDistros = @(& wsl.exe --list --quiet 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not list WSL distributions: $($installedDistros -join [Environment]::NewLine)"
}
$installedDistros = @($installedDistros | ForEach-Object { $_.ToString().Replace("`0", '').Trim() })
if ($installedDistros -notcontains $Distro) {
    throw "WSL distribution '$Distro' is not installed."
}

Invoke-UpdateStep 'WinGet packages' {
    & winget.exe upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
}

Invoke-UpdateStep 'WSL runtime' {
    & wsl.exe --update
}

Invoke-UpdateStep "$Distro packages" {
    & wsl.exe --distribution $Distro --user root --exec /bin/sh -c `
        'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade'
}

if ($failures.Count -gt 0) {
    throw "Updates failed: $($failures -join ', ')."
}

Write-Host "WinGet, WSL runtime, and $Distro package updates complete. Restart Windows or WSL if an update requests it."
