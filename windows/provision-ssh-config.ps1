$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'ssh-config'
$sshDirectory = Join-Path $env:USERPROFILE '.ssh'
$target = Join-Path $sshDirectory 'config'
$backup = Join-Path $sshDirectory 'config.pre-bootstrap.bak'

if (-not (Test-Path $source -PathType Leaf)) { throw "Windows SSH config is missing: $source" }
New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sshDirectory 'config.d') -Force | Out-Null

if ((Test-Path $target -PathType Leaf) -and
    (Get-FileHash $target).Hash -eq (Get-FileHash $source).Hash) {
    return
}
if ((Test-Path $target -PathType Leaf) -and -not (Test-Path $backup)) {
    Copy-Item $target $backup
}
Copy-Item $source $target -Force
Write-Host "Installed Windows SSH client config at $target"
