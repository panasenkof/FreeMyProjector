#requires -Version 5.1
<#
.SYNOPSIS
  Verify a private P-04B snapshot, then PREVIEW differences from a live projector.
.DESCRIPTION
  Read-only. DOES NOT restore HOME, change package states, write settings or files,
  launch activities or install APKs. Requires exact MiProjM05/.4185 firmware.
  Reports differences, not executable recovery commands.
.EXAMPLE
  .\tools\Compare-ProjectorBaseline.ps1 -SnapshotDirectory 'D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d' -VerifyOnly
.EXAMPLE
  .\tools\Compare-ProjectorBaseline.ps1 -SnapshotDirectory 'D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d' -AdbPath $adb
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SnapshotDirectory,
    [string]$AdbPath = 'adb',
    [switch]$VerifyOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Reason) {
    throw "P-04B comparison STOPPED: $Reason. No projector settings were changed."
}
function PackageName([string]$Name) {
    return $Name -cmatch '^(?:android|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)$'
}
function ComponentName([string]$Name) {
    return $Name -cmatch '^[A-Za-z][A-Za-z0-9_.]*/[A-Za-z0-9_.$]+$' -and $Name.Length -le 180
}
function Read-Adb {
    param([string[]]$Arguments,[switch]$AllowEmpty)
    try {
        $global:LASTEXITCODE = 0
        $raw = & $script:AdbExecutable @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { Fail 'ADB command failed' }
        $value = (@($raw) -join [Environment]::NewLine).Trim()
        if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) { Fail 'ADB response empty' }
        return [string]$value
    } catch {
        # Do not relay raw stderr, which can include device serials or IP addresses.
        Fail 'ADB read failed'
    }
}
function Get-Property([string]$Key) {
    $value = Read-Adb -Arguments @('shell','getprop',$Key)
    if ($value.Length -gt 110 -or $value -notmatch '^[A-Za-z0-9._/()+ -]+$') { Fail 'Invalid device property' }
    return $value
}
function Read-PackageSet {
    param([string[]]$Query,[switch]$AllowEmpty)
    $reply = Read-Adb -Arguments $Query -AllowEmpty:$AllowEmpty
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($reply)) {
        if (-not $AllowEmpty) { Fail 'Package list empty' }
        return ,$set
    }
    foreach ($line in ($reply -split '\r?\n')) {
        if (-not $line.StartsWith('package:')) { Fail 'Invalid package-list line' }
        $name = $line.Substring(8)
        if (-not (PackageName $name) -or -not $set.Add($name)) { Fail 'Malformed or duplicated package name' }
    }
    if (-not $AllowEmpty -and $set.Count -lt 15) { Fail 'Package inventory too small' }
    return ,$set
}

# Validate saved bytes BEFORE any ADB interaction.
if (-not (Test-Path -LiteralPath $SnapshotDirectory -PathType Container)) { Fail 'Snapshot folder not found' }
$folder = (Resolve-Path -LiteralPath $SnapshotDirectory).Path
$jsonPath = Join-Path $folder 'baseline.private.json'
$hashPath = Join-Path $folder 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $hashPath -PathType Leaf)) { Fail 'Snapshot or SHA256SUMS file missing' }
$sumLines = @(Get-Content -LiteralPath $hashPath)
if ($sumLines.Count -ne 1) { Fail 'Invalid SHA256SUMS format' }
if ($sumLines[0] -cmatch '^([0-9a-fA-F]{64})  baseline\.private\.json$') {
    $expectedHash = $Matches[1].ToLowerInvariant()
} else {
    Fail 'Invalid SHA256SUMS format'
}
$actualHash = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -cne $expectedHash) { Fail 'Snapshot SHA256 mismatch after copy/move' }
try {
    $baseline = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
} catch { Fail 'Invalid snapshot JSON' }
if ($null -eq $baseline -or $baseline.schema_version -ne 1 -or
    $baseline.status -cne 'read-only-baseline') { Fail 'Unsupported snapshot schema/status' }

$firmware = $baseline.firmware
if ($null -eq $firmware -or $firmware.model -cne 'MiProjM05' -or
    $firmware.device -cne 'eva' -or [string]$firmware.android -cne '9' -or
    [string]$firmware.sdk -cne '28' -or $firmware.build -cne 'PQ3B.190705.003.4185') {
    Fail 'Snapshot firmware is not audited MiProjM05/.4185'
}
$originalHome = [string]$baseline.home.resolved
if ($originalHome -cne 'com.google.android.tvlauncher/.MainActivity') {
    Fail 'Snapshot does not contain audited original HOME'
}
$stateObject = $baseline.package_states
if ($null -eq $stateObject -or $stateObject -isnot [pscustomobject]) { Fail 'Missing package_states object' }
$states = @{}
foreach ($entry in @($stateObject.PSObject.Properties)) {
    if (-not (PackageName $entry.Name) -or
        $entry.Value -cnotin @('enabled','disabled')) { Fail 'Invalid saved package/state' }
    if ($states.ContainsKey($entry.Name)) { Fail 'Duplicate saved package name' }
    $states.Add($entry.Name,[string]$entry.Value)
}
if ($states.Count -lt 15) { Fail 'Snapshot packages missing' }
$protected = @(
    'com.google.android.tvlauncher','com.android.tv.settings',
    'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
    'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
    'com.droidlogic','com.droidlogic.tvinput','com.android.camera2'
)
foreach ($name in $protected) {
    if (-not $states.ContainsKey($name) -or $states[$name] -cne 'enabled') {
        Fail 'Audited factory package missing/disabled in snapshot'
    }
}
if ($VerifyOnly) {
    [pscustomobject]@{
        status='verified'
        mode='offline-snapshot-integrity'
        sha256='match'
        installed_packages=$states.Count
        disabled_packages=@($states.Values | Where-Object { $_ -eq 'disabled' }).Count
        device_access='none'
        device_writes=0
        home_switch_blocked=$true
        note='Snapshot verified locally. This is NOT a firmware/calibration backup.'
    } | ConvertTo-Json -Depth 4
    return
}

if ([IO.Path]::IsPathRooted($AdbPath) -and (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    $script:AdbExecutable = (Resolve-Path -LiteralPath $AdbPath).Path
} else {
    $command = Get-Command -Name $AdbPath -ErrorAction SilentlyContinue
    if ($null -eq $command -or $command.CommandType -notin @('Application','ExternalScript')) {
        Fail 'ADB executable unavailable'
    }
    $script:AdbExecutable = $command.Source
}
$rawDevices = Read-Adb -Arguments @('devices')
$devices = @()
foreach ($line in ($rawDevices -split '\r?\n')) {
    if ($line -match '^\s*\S+\s+(device|offline|unauthorized|recovery|sideload|bootloader)(?:\s|$)') {
        $devices += $Matches[1]
    }
}
if ($devices.Count -ne 1 -or $devices[0] -ne 'device') { Fail 'Exactly one authorized projector required' }
$live = [ordered]@{
    model=Get-Property 'ro.product.model'
    device=Get-Property 'ro.product.device'
    android=Get-Property 'ro.build.version.release'
    sdk=Get-Property 'ro.build.version.sdk'
    build=Get-Property 'ro.build.display.id'
}
if ($live.model -cne $firmware.model -or $live.device -cne $firmware.device -or
    $live.android -cne [string]$firmware.android -or $live.sdk -cne [string]$firmware.sdk -or
    $live.build -cne $firmware.build) { Fail 'Live device firmware differs from verified snapshot' }

$homeResult = Read-Adb -Arguments @('shell','cmd','package','resolve-activity','--brief',
    '-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$homeComponents = @($homeResult -split '\r?\n' | Where-Object { ComponentName $_ })
if ($homeComponents.Count -ne 1) { Fail 'Ambiguous or unresolved live HOME' }
$currentHome = [string]$homeComponents[0]
if ($currentHome -match '(?i)FallbackHome|SetupWizard') { Fail 'Fallback/setup HOME is not restorable HOME' }

$claims = Read-Adb -Arguments @('shell','cmd','package','query-activities','--brief',
    '-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$known = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($entry in ($claims -split '\r?\n')) {
    $entry = $entry.Trim()
    if (ComponentName $entry) { [void]$known.Add($entry) }
}
if (-not $known.Contains($originalHome)) { Fail 'Factory HOME is not a current HOME claimant' }

$installed = Read-PackageSet -Query @('shell','pm','list','packages')
$disabled = Read-PackageSet -Query @('shell','pm','list','packages','-d') -AllowEmpty
$enabled = Read-PackageSet -Query @('shell','pm','list','packages','-e')
foreach ($name in $disabled) {
    if (-not $installed.Contains($name) -or $enabled.Contains($name)) { Fail 'Inconsistent live disabled package list' }
}
foreach ($name in $enabled) {
    if (-not $installed.Contains($name)) { Fail 'Inconsistent live enabled package list' }
}
if ($installed.Count -ne $disabled.Count+$enabled.Count) { Fail 'Live package states are incomplete' }
foreach ($name in $protected) {
    if (-not $enabled.Contains($name)) { Fail 'Required factory package missing/disabled on live projector' }
}
$changed = @()
$missing = @()
$added = @()
foreach ($name in @($states.Keys | Sort-Object)) {
    if (-not $installed.Contains($name)) {
        $missing += $name
    } else {
        $currentState = if ($disabled.Contains($name)) { 'disabled' } else { 'enabled' }
        if ($currentState -cne $states[$name]) {
            $changed += [pscustomobject]@{
                package=$name
                baseline=$states[$name]
                current=$currentState
                review='Would require separate restoration approval; NOT executed'
            }
        }
    }
}
foreach ($name in @($installed | Sort-Object)) {
    if (-not $states.ContainsKey($name)) { $added += $name }
}
$differs = ($currentHome -cne $originalHome -or $changed.Count -gt 0 -or
    $missing.Count -gt 0 -or $added.Count -gt 0)
[pscustomobject]@{
    schema_version=1
    mode='read-only-difference-preview'
    status=if ($differs) { 'review-required' } else { 'matches-baseline' }
    snapshot_sha256='match'
    firmware_match=$true
    home=[ordered]@{
        baseline=$originalHome
        current=$currentHome
        differs=($currentHome -cne $originalHome)
    }
    packages=[ordered]@{
        baseline=$states.Count
        current=$installed.Count
        changed_state=$changed
        absent_from_device=@($missing)
        new_since_baseline=@($added)
    }
    home_switch_blocked=$true
    device_writes=0
    note='PREVIEW ONLY: No restoration commands, package changes, settings writes or firmware operations.'
} | ConvertTo-Json -Depth 8
