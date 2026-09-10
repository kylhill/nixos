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
    Write-Host "Restart Windows if requested, then rerun this script to update and verify the distribution."
    exit 0
}

# Update the runtime before inspecting or converting an existing distribution.
Invoke-Wsl -Arguments @("--update")

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

Write-Host ""
Write-Host "Windows-side WSL setup complete."
Write-Host ""
Write-Host "If Windows requests a restart, reboot now."
Write-Host ""
Write-Host "Then launch $Distro with:"
Write-Host ""
Write-Host "    wsl -d $Distro"
Write-Host ""
Write-Host "On the first launch, create your Linux user."
Write-Host "Ensure /etc/wsl.conf enables systemd; bootstrap-home.sh prints exact instructions if needed."
Write-Host "Then run these commands inside ${Distro}:"
Write-Host ""
Write-Host "    sudo apt-get update"
Write-Host "    sudo apt-get install -y git"
Write-Host "    git clone https://git.tacomafia.net/kylhill/nixos.git ~/nixos"
Write-Host "    ~/nixos/scripts/bootstrap-home.sh"
