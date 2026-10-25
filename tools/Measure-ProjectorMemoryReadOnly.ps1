#requires -Version 5.1
<#
.SYNOPSIS
  P-07 read-only RAM baseline; safe with stock HOME, MiProjM05 firmware .4185.
.DESCRIPTION
  Requires a previously verified local P-04B snapshot and P-04E scope check.
  Does not install APK, change HOME, power, ADB transport or OEM settings.
  Prints aggregate memory figures only, never raw device output.
.EXAMPLE
  .\tools\Measure-ProjectorMemoryReadOnly.ps1 -SnapshotDirectory $folder -AdbPath $adb -Phase stock-before
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SnapshotDirectory,
    [string]$AdbPath = 'adb',
    [ValidateSet('stock-before','preview-stock-home','preview-settings','preview-after-back')]
    [string]$Phase = 'stock-before'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-Probe([string]$Reason) {
    throw "P-07 STOP: $Reason. Read-only; no projector settings changed."
}
function Invoke-ProbeRead([string[]]$Arguments) {
    # Centralized fixed-command allowlist: never interpolate a user command.
    $key = $Arguments -join ' '
    $permitted = @(
        'devices',
        'shell cat /proc/meminfo',
        'shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME',
        'shell dumpsys meminfo com.fader.freemyprojector'
    )
    if ($key -cnotin $permitted) { Stop-Probe 'Command outside allowlist' }
    try {
        $global:LASTEXITCODE = 0
        $raw = & $script:AdbExecutable @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { Stop-Probe 'ADB read returned nonzero' }
        $reply = (@($raw) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($reply)) { Stop-Probe 'ADB read returned empty response' }
        return [string]$reply
    } catch {
        # Never echo raw ADB stderr, which may contain serials or addresses.
        Stop-Probe 'ADB read failed'
    }
}

$preflight = Join-Path $PSScriptRoot 'Test-ProjectorUser0Scope.ps1'
if (-not (Test-Path -LiteralPath $preflight -PathType Leaf)) { Stop-Probe 'Scope verifier missing' }
if (-not (Test-Path -LiteralPath $SnapshotDirectory -PathType Container)) { Stop-Probe 'Snapshot folder missing' }
if ([IO.Path]::IsPathRooted($AdbPath) -and (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    $script:AdbExecutable = (Resolve-Path -LiteralPath $AdbPath).Path
} else {
    $found = Get-Command -Name $AdbPath -ErrorAction SilentlyContinue
    if ($null -eq $found -or $found.CommandType -notin @('Application','ExternalScript')) {
        Stop-Probe 'ADB executable unavailable'
    }
    $script:AdbExecutable = $found.Source
}
try {
    $scopeText = & $preflight -SnapshotDirectory $SnapshotDirectory -AdbPath $script:AdbExecutable
    $scope = (@($scopeText) -join [Environment]::NewLine) | ConvertFrom-Json
    if ($scope.status -cne 'user0-matches-baseline' -or
        $scope.snapshot_sha256 -cne 'match' -or
        [int]$scope.device_writes -ne 0 -or
        [int]$scope.active_android_user -ne 0) {
        Stop-Probe 'Snapshot or active Android user differs'
    }
} catch {
    Stop-Probe 'Scope preflight failed'
}
$devices = Invoke-ProbeRead @('devices')
$online = @($devices -split '\r?\n' | Where-Object {
    $_ -match '^\s*\S+\s+(device|unauthorized|offline|recovery|sideload|bootloader)(?:\s|$)'
})
if ($online.Count -ne 1 -or $online[0] -notmatch '^\s*\S+\s+device(?:\s|$)') {
    Stop-Probe 'Exactly one authorized device required'
}
$homeText = Invoke-ProbeRead @('shell','cmd','package','resolve-activity','--brief',
    '-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$homeComponents = @($homeText -split '\r?\n' | Where-Object { $_ -cmatch '^[A-Za-z][\w.]*/[\w.$]+$' })
if ($homeComponents.Count -ne 1 -or
    $homeComponents[0] -cne 'com.google.android.tvlauncher/.MainActivity') {
    Stop-Probe 'Factory HOME not unambiguously active'
}
$parserFile = Join-Path $PSScriptRoot 'ProjectorMemoryParsers.ps1'
if (-not (Test-Path -LiteralPath $parserFile -PathType Leaf)) { Stop-Probe 'Memory parser missing' }
. $parserFile
$memoryText = Invoke-ProbeRead @('shell','cat','/proc/meminfo')
try { $numbers = ConvertFrom-ProjectorMeminfo $memoryText }
catch { Stop-Probe 'Invalid or inconsistent memory counters' }
$appPss = $null
if ($Phase -ne 'stock-before') {
    $appRaw = Invoke-ProbeRead @('shell','dumpsys','meminfo','com.fader.freemyprojector')
    $appPss = ConvertFrom-ProjectorPss $appRaw
}
[pscustomobject]@{
    schema_version = 1
    status = 'read-only-sample'
    phase = $Phase
    model = 'MiProjM05'
    build = 'PQ3B.190705.003.4185'
    stock_home_unchanged = $true
    mem_total_kib = $numbers.MemTotal
    mem_available_kib = $numbers.MemAvailable
    app_pss_kib = $appPss
    app_pss_note = if ($null -eq $appPss) { 'not-available-or-not-unambiguous' } else { 'parsed-from-dumpsys-meminfo' }
    cpu = 'not-measured'
    temperature = 'not-measured'
    fps = 'not-measured'
    device_writes = 0
    note = 'Single instantaneous sample only; no device changes; not a sleep or thermal safety test'
} | ConvertTo-Json -Depth 3
