# Parser and mocked orchestration checks. Never invoke native Windows tools,
# install packages, change WSL, provision credentials, or apply configuration.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoDir = Split-Path $PSScriptRoot -Parent

foreach ($file in @((Get-ChildItem (Join-Path $repoDir 'windows') -Filter '*.ps1').FullName) + $PSCommandPath) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell syntax failed for ${file}: $($parseErrors.Message -join '; ')"
    }
}

$fixtureDir = [IO.Directory]::CreateTempSubdirectory('nixos-windows-').FullName
try {
    # Strip the administrator requirement only from disposable test copies.
    # The original scripts above are parsed with every directive intact.
    foreach ($name in 'verify.ps1', 'update.ps1') {
        $content = Get-Content (Join-Path $repoDir "windows/$name") -Raw
        $content = $content -replace '(?im)^#Requires -RunAsAdministrator\r?\n', ''
        Set-Content (Join-Path $fixtureDir $name) $content
    }
    Copy-Item (Join-Path $repoDir 'windows/*.winget') $fixtureDir
    foreach ($file in Get-ChildItem $fixtureDir -Filter '*.winget') { $file.IsReadOnly = $false }

    $global:NixosWindowsFixture = @{
        Calls = [Collections.Generic.List[string]]::new()
        FailWinget = ''
        FailWsl = ''
        InstalledDistros = @("Ubuntu`0")
    }
    function winget.exe {
        $call = "winget $($args -join ' ')"
        $global:NixosWindowsFixture.calls.Add($call)
        $global:LASTEXITCODE = if ($global:NixosWindowsFixture.failWinget -and $call -like "*$($global:NixosWindowsFixture.failWinget)*") { 17 } else { 0 }
    }
    function wsl.exe {
        $call = "wsl $($args -join ' ')"
        $global:NixosWindowsFixture.calls.Add($call)
        $global:LASTEXITCODE = if ($global:NixosWindowsFixture.failWsl -and $call -like "*$($global:NixosWindowsFixture.failWsl)*") { 18 } else { 0 }
        if (($args -join ' ') -eq '--list --quiet') { $global:NixosWindowsFixture.installedDistros }
    }
    function Invoke-Case {
        param([string]$Name, [hashtable]$Arguments, [string]$ExpectedError = '')
        $global:NixosWindowsFixture.calls.Clear()
        $message = ''
        try {
            & (Join-Path $fixtureDir $Name) @Arguments *> $null
        } catch {
            $message = $_.Exception.Message
        }
        if ($ExpectedError) {
            if ($message -notlike "*$ExpectedError*") {
                throw "Expected '$ExpectedError', got '$message': $Name"
            }
        } elseif ($message) {
            throw "Unexpected failure in ${Name}: $message"
        }
    }
    function Assert-Calls {
        param([string[]]$Expected)
        if (($global:NixosWindowsFixture.calls -join "`n") -cne ($Expected -join "`n")) {
            throw "Expected calls:`n$($Expected -join "`n")`nActual calls:`n$($global:NixosWindowsFixture.calls -join "`n")"
        }
    }

    Invoke-Case verify.ps1 @{ Scope = 'Configuration' }
    Assert-Calls @("winget configure test -f $(Join-Path $fixtureDir 'configuration.winget')")
    Invoke-Case verify.ps1 @{ Scope = 'Packages'; Profile = 'Home' }
    Assert-Calls @(
        "winget configure test -f $(Join-Path $fixtureDir 'packages-common.winget')",
        "winget configure test -f $(Join-Path $fixtureDir 'packages-home.winget')"
    )
    Invoke-Case verify.ps1 @{ Profile = 'Work' }
    Assert-Calls @(
        "winget configure test -f $(Join-Path $fixtureDir 'configuration.winget')",
        "winget configure test -f $(Join-Path $fixtureDir 'packages-common.winget')",
        "winget configure test -f $(Join-Path $fixtureDir 'packages-work.winget')"
    )
    Invoke-Case verify.ps1 @{ Scope = 'Packages' } '-Profile Home or Work is required'
    Assert-Calls @()
    Remove-Item (Join-Path $fixtureDir 'packages-work.winget')
    Invoke-Case verify.ps1 @{ Profile = 'Work' } 'WinGet configuration is missing'
    Assert-Calls @()
    Copy-Item (Join-Path $repoDir 'windows/packages-work.winget') $fixtureDir
    (Get-Item (Join-Path $fixtureDir 'packages-work.winget')).IsReadOnly = $false
    $global:NixosWindowsFixture.failWinget = 'configuration.winget'
    Invoke-Case verify.ps1 @{ Profile = 'Home' } 'exit code 17'
    Assert-Calls @("winget configure test -f $(Join-Path $fixtureDir 'configuration.winget')")
    $global:NixosWindowsFixture.failWinget = ''

    $updateCalls = @(
        'wsl --list --quiet',
        'winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity',
        'wsl --update',
        'wsl --distribution Ubuntu --user root --exec /bin/sh -c apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade'
    )
    Invoke-Case update.ps1 @{}
    Assert-Calls $updateCalls
    $global:NixosWindowsFixture.failWinget = 'upgrade'
    Invoke-Case update.ps1 @{} 'Updates failed: WinGet packages'
    Assert-Calls $updateCalls
    $global:NixosWindowsFixture.failWsl = '--update'
    Invoke-Case update.ps1 @{} 'Updates failed: WinGet packages, WSL runtime'
    Assert-Calls $updateCalls
    $global:NixosWindowsFixture.failWinget = ''
    $global:NixosWindowsFixture.failWsl = '--list'
    Invoke-Case update.ps1 @{} 'Could not list WSL distributions'
    Assert-Calls @('wsl --list --quiet')
    $global:NixosWindowsFixture.failWsl = ''
    $global:NixosWindowsFixture.installedDistros = @('Other')
    Invoke-Case update.ps1 @{} "WSL distribution 'Ubuntu' is not installed"
    Assert-Calls @('wsl --list --quiet')
} finally {
    [IO.Directory]::Delete($fixtureDir, $true)
    Remove-Variable NixosWindowsFixture -Scope Global -ErrorAction SilentlyContinue
}
Write-Host 'Windows parser and orchestration fixtures passed.'
