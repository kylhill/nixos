#Requires -RunAsAdministrator

param(
    [ValidateSet('Home', 'Work')]
    [string]$Profile,

    [switch]$Verify,

    [switch]$WindowsOnly
)

$ErrorActionPreference = 'Stop'
$wslBootstrap = Join-Path $PSScriptRoot 'bootstrap-wsl.ps1'
$sshProvision = Join-Path $PSScriptRoot 'provision-ssh-agent.ps1'
$sshConfigProvision = Join-Path $PSScriptRoot 'provision-ssh-config.ps1'
$verifyScript = Join-Path $PSScriptRoot 'verify.ps1'

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

$nativeConfiguration = Join-Path $PSScriptRoot 'configuration.winget'
$configurationFiles = @(
    $nativeConfiguration,
    (Join-Path $PSScriptRoot 'packages-common.winget'),
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
if ($Profile) { Write-Host "Using application profile: $Profile" }
foreach ($configuration in $configurationFiles) {
    if (-not (Test-Path $configuration -PathType Leaf)) {
        throw "WinGet configuration is missing: $configuration"
    }
}

# `winget configure validate` currently performs a public-catalog provenance
# audit that rejects native DSC v3 resources such as Microsoft.WinGet/Package,
# Microsoft.Windows/Registry, and Microsoft.DSC.Transitional/*. Applying the
# document still performs schema/resource validation; optional post-apply tests
# verify the resulting desired state when -Verify is supplied.
foreach ($configuration in $configurationFiles) {
    Write-Host "Applying $(Split-Path $configuration -Leaf)..."
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-WinGet -Arguments @('configure', '-f', $configuration,
        '--accept-configuration-agreements', '--disable-interactivity')
    $timer.Stop()
    Write-Host "Applied $(Split-Path $configuration -Leaf) in $($timer.Elapsed)."
}

if ($Verify) { & $verifyScript -Profile $Profile }

& $sshConfigProvision
& $sshProvision

if ($WindowsOnly) {
    Write-Host 'Windows configuration complete. No reboot was performed automatically.'
    exit 0
}

& $wslBootstrap
if ($LASTEXITCODE -eq 10) { exit 0 }
if ($LASTEXITCODE -ne 0) {
    throw "WSL bootstrap failed with exit code $LASTEXITCODE"
}

Write-Host 'Windows and WSL bootstrap complete. No reboot was performed automatically.'
