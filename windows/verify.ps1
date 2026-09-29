#Requires -RunAsAdministrator

param(
    [ValidateSet('All', 'Configuration', 'Packages')]
    [string]$Scope = 'All',

    [ValidateSet('Home', 'Work')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
if ($Scope -ne 'Configuration' -and -not $Profile) {
    throw '-Profile Home or Work is required when verifying packages.'
}
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store, then rerun this script.'
}

$configurationFiles = @(
    if ($Scope -ne 'Packages') {
        Join-Path $PSScriptRoot 'configuration.winget'
    }
    if ($Scope -ne 'Configuration') {
        Join-Path $PSScriptRoot 'packages-common.winget'
        Join-Path $PSScriptRoot "packages-$($Profile.ToLowerInvariant()).winget"
    }
)
foreach ($configuration in $configurationFiles) {
    if (-not (Test-Path $configuration -PathType Leaf)) {
        throw "WinGet configuration is missing: $configuration"
    }
}
foreach ($configuration in $configurationFiles) {
    Write-Host "Testing $(Split-Path $configuration -Leaf)..."
    $timer = [Diagnostics.Stopwatch]::StartNew()
    & winget.exe configure test -f $configuration
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet test failed for $configuration with exit code $LASTEXITCODE"
    }
    $timer.Stop()
    Write-Host "Tested $(Split-Path $configuration -Leaf) in $($timer.Elapsed)."
}

Write-Host 'Windows configuration verification complete.'
