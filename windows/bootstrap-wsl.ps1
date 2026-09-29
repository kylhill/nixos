#Requires -RunAsAdministrator

param(
    [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

function Invoke-Wsl {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = @(& wsl.exe @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $message = "wsl.exe $($Arguments -join ' ') failed with exit code $exitCode"
        if ($output) {
            $message += ": $($output -join [Environment]::NewLine)"
        }

        throw $message
    }

    return $output
}

$linuxBootstrap = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\bootstrap-home.sh'
if (-not (Test-Path $linuxBootstrap -PathType Leaf)) {
    throw "Linux bootstrap is missing: $linuxBootstrap"
}

Write-Host "Configuring WSL..."

$installedDistros = @()

try {
    $installedDistros = @(
        Invoke-Wsl -Arguments @("--list", "--quiet") |
            ForEach-Object { $_.Replace("`0", "").Trim() } |
            Where-Object { $_ }
    )
} catch {
    $wslFeature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName Microsoft-Windows-Subsystem-Linux

    if ($wslFeature.State -ne "Disabled") {
        throw
    }

    Write-Host "The Windows Subsystem for Linux feature is not enabled yet."
}

if ($installedDistros -contains $Distro) {
    Write-Host "$Distro is already installed."
} else {
    Write-Host "Installing WSL and $Distro..."
    Invoke-Wsl -Arguments @("--install", "--distribution", $Distro, "--no-launch")

    Write-Host ""
    Write-Host "Initial WSL installation completed."
    Write-Host "Restart Windows if requested, launch $Distro to create the kyleh Linux user, then rerun the bootstrap command."
    # A new distribution needs its first launch/user setup (and often a reboot)
    # before the Linux bootstrap can run. The top-level bootstrap is rerunnable.
    exit 10
}

# Prefer WSL2 for all future distributions.
Invoke-Wsl -Arguments @("--set-default-version", "2")

$escapedDistro = [Regex]::Escape($Distro)
$distroVersion = $null
$verboseDistros = @(
    Invoke-Wsl -Arguments @("--list", "--verbose") |
        ForEach-Object { $_.Replace("`0", "").TrimEnd() }
)

foreach ($line in $verboseDistros) {
    if ($line -match "^\s*\*?\s*$escapedDistro\s+\S+\s+([12])\s*$") {
        $distroVersion = [int]$Matches[1]
        break
    }
}

if ($null -eq $distroVersion) {
    throw "Could not determine the WSL version for distribution '$Distro'."
}

if ($distroVersion -eq 1) {
    Write-Host "Converting $Distro from WSL1 to WSL2..."
    Invoke-Wsl -Arguments @("--set-version", $Distro, "2")
} else {
    Write-Host "$Distro is already using WSL2."
}

Write-Host "Windows-side WSL setup complete."
# Run the checked-out script through its mounted path. It installs Linux Git
# before cloning the repository inside Ubuntu; no native Windows Git is needed.
$wslPathOutput = @(Invoke-Wsl -Arguments @('-d', $Distro, '--exec', 'wslpath', '-a', '-u', $linuxBootstrap))
if ($wslPathOutput.Count -ne 1) { throw 'wslpath did not return exactly one Linux bootstrap path.' }
$wslPath = $wslPathOutput[0].ToString().Trim()
if (-not $wslPath) { throw 'wslpath returned an empty Linux bootstrap path.' }
Write-Host "Bootstrapping Nix and Home Manager inside ${Distro}..."
& wsl.exe -d $Distro --exec bash -- $wslPath
if ($LASTEXITCODE -ne 0) {
    throw "Linux bootstrap failed with exit code $LASTEXITCODE. Correct the reported issue and rerun the bootstrap command."
}
exit 0
