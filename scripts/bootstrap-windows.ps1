#Requires -RunAsAdministrator

param(
    [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

Write-Host "Configuring WSL..."

# See what is already installed. wsl.exe may return an error if WSL
# hasn't been initialized yet, so tolerate that here.
$installedDistros = @()

try {
    $installedDistros = @(
        wsl.exe --list --quiet 2>$null |
            ForEach-Object { $_.Replace("`0", "").Trim() } |
            Where-Object { $_ }
    )
} catch {
    # Fresh Windows install; wsl --install below will handle it.
}

if ($installedDistros -contains $Distro) {
    Write-Host "$Distro is already installed."
} else {
    Write-Host "Installing WSL and $Distro..."
    wsl.exe --install --distribution $Distro --no-launch

    if ($LASTEXITCODE -ne 0) {
        throw "WSL installation failed with exit code $LASTEXITCODE"
    }
}

# Prefer WSL2 for all future distributions.
wsl.exe --set-default-version 2

# Update the Store-delivered WSL runtime when available.
try {
    wsl.exe --update
} catch {
    Write-Warning "WSL update could not be completed yet. This can happen before the required reboot."
}

Write-Host ""
Write-Host "Windows-side WSL setup complete."
Write-Host ""
Write-Host "If Windows requests a restart, reboot now."
Write-Host ""
Write-Host "Then launch Ubuntu with:"
Write-Host ""
Write-Host "    wsl -d $Distro"
Write-Host ""
Write-Host "On the first launch, create your Linux user."
Write-Host "After that, run bootstrap-home.sh from inside Ubuntu."
