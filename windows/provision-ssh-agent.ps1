#Requires -RunAsAdministrator

param(
    [string]$SecretFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'secrets\home.yaml')
)

$ErrorActionPreference = 'Stop'
$sops = (Get-Command sops.exe -ErrorAction SilentlyContinue).Source
if (-not $sops) {
    foreach ($link in @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\sops.exe'),
        (Join-Path $env:ProgramFiles 'WinGet\Links\sops.exe')
    )) {
        if (Test-Path $link) { $sops = $link; break }
    }
}
if (-not $sops) { throw 'sops.exe is unavailable. Open a new PowerShell session after WinGet installs SOPS and rerun.' }
if (-not (Test-Path $SecretFile -PathType Leaf)) { throw "Encrypted SSH secret is missing: $SecretFile" }

$service = Get-Service -Name ssh-agent -ErrorAction Stop
if ($service.StartType -ne 'Automatic') { Set-Service -Name ssh-agent -StartupType Automatic }
if ($service.Status -ne 'Running') { Start-Service -Name ssh-agent }

$secureKey = Read-Host 'SOPS age secret key for the Windows SSH agent (blank to skip)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
    $ageKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
}
if ([string]::IsNullOrWhiteSpace($ageKey)) {
    Write-Host 'Skipping SSH key loading.'
    return
}

$scratch = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
$privateKey = Join-Path $scratch 'id_ed25519'
try {
    New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null
    $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $scratch /inheritance:r /grant:r ('*' + $userSid + ':(OI)(CI)F') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not restrict the temporary SSH key directory.' }

    $env:SOPS_AGE_KEY = $ageKey
    $ageKey = $null
    # Windows PowerShell 5.1 strips unescaped quotes from native arguments.
    # PowerShell 7's standard argument passing preserves them as-is.
    $extractPath = '["ssh"]["private-key"]'
    if ($PSVersionTable.PSVersion.Major -lt 7 -or
        $PSNativeCommandArgumentPassing -eq 'Legacy') {
        $extractPath = '[\"ssh\"][\"private-key\"]'
    }
    & $sops decrypt --extract $extractPath --output $privateKey $SecretFile 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Could not decrypt the SSH key with the supplied age identity.' }
    Remove-Item Env:SOPS_AGE_KEY -ErrorAction SilentlyContinue

    & "$env:WINDIR\System32\OpenSSH\ssh-add.exe" $privateKey
    if ($LASTEXITCODE -ne 0) { throw 'Could not add the decrypted SSH key to the Windows OpenSSH agent.' }
    Write-Host 'Loaded the shared SSH key into the Windows OpenSSH agent.'
} finally {
    Remove-Item Env:SOPS_AGE_KEY -ErrorAction SilentlyContinue
    $ageKey = $null
    if (Test-Path $scratch) { Remove-Item $scratch -Recurse -Force -ErrorAction Stop }
}
