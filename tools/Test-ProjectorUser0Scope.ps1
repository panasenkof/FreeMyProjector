#requires -Version 5.1
<#
.SYNOPSIS
  P-04E read-only check of MiProjM05 Android 9 package-state scope for user 0.
.DESCRIPTION
  Verifies existing SHA256 baseline offline before any ADB query. Compares package
  inventories with and without --user 0 to the saved baseline. Only returns counts
  and status; never changes HOME, packages, pairing or projection settings.
.EXAMPLE
  .\tools\Test-ProjectorUser0Scope.ps1 -SnapshotDirectory 'D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d' -AdbPath $adb
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SnapshotDirectory,
    [string]$AdbPath = 'adb'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Stop-Scope([string]$Why) {
    throw "P-04E read-only scope STOPPED: $Why. No projector settings changed."
}
function Invoke-Read {
    param([string[]]$Arguments,[switch]$AllowEmpty)
    try {
        $global:LASTEXITCODE=0
        $raw = & $script:AdbExecutable @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { Stop-Scope 'ADB command failed' }
        $reply = (@($raw) -join [Environment]::NewLine).Trim()
        if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($reply)) { Stop-Scope 'ADB output missing' }
        return [string]$reply
    } catch {
        # Never disclose raw ADB stderr, serial, MAC or IP.
        Stop-Scope 'ADB read failed'
    }
}
function Valid-Package([string]$Name) {
    return $Name -cmatch '^(?:android|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)$'
}
function Read-Set {
    param([string[]]$Flags,[switch]$AllowEmpty)
    $reply = Invoke-Read -Arguments (@('shell','pm','list','packages') + $Flags) -AllowEmpty:$AllowEmpty
    $result=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($reply)) {
        if (-not $AllowEmpty) { Stop-Scope 'Empty package inventory' }
        return ,$result
    }
    foreach ($line in ($reply -split '\r?\n')) {
        if ($line -cnotmatch '^package:(.+)$') { Stop-Scope 'Invalid package list output' }
        $name=$Matches[1]
        if (-not (Valid-Package $name) -or -not $result.Add($name)) {
            Stop-Scope 'Malformed or duplicate package list output'
        }
    }
    if (-not $AllowEmpty -and $result.Count -lt 15) { Stop-Scope 'Package inventory too small' }
    return ,$result
}
function Read-Partition {
    param([string[]]$UserFlag)
    $all=Read-Set -Flags $UserFlag
    $enabled=Read-Set -Flags (@('-e')+$UserFlag)
    $disabled=Read-Set -Flags (@('-d')+$UserFlag) -AllowEmpty
    foreach ($name in $enabled) {
        if (-not $all.Contains($name) -or $disabled.Contains($name)) {
            Stop-Scope 'Enabled/disabled inventory contradicts installed packages'
        }
    }
    foreach ($name in $disabled) {
        if (-not $all.Contains($name)) { Stop-Scope 'Disabled package missing from installed list' }
    }
    if ($all.Count -ne $enabled.Count + $disabled.Count) {
        Stop-Scope 'Enabled/disabled inventory incomplete'
    }
    return [pscustomobject]@{all=$all;enabled=$enabled;disabled=$disabled}
}
function State-At($Inventory,[string]$Name) {
    if (-not $Inventory.all.Contains($Name)) { return 'missing' }
    if ($Inventory.disabled.Contains($Name)) { return 'disabled' }
    return 'enabled'
}
# First validate saved snapshot with existing verification logic and NO ADB.
$verify = Join-Path $PSScriptRoot 'Compare-ProjectorBaseline.ps1'
if (-not (Test-Path -LiteralPath $verify -PathType Leaf)) { Stop-Scope 'Baseline verifier missing' }
$validation = (& $verify -SnapshotDirectory $SnapshotDirectory -VerifyOnly) | ConvertFrom-Json
if ($validation.status -cne 'verified' -or $validation.sha256 -cne 'match' -or
    $validation.device_access -cne 'none' -or [int]$validation.device_writes -ne 0) {
    Stop-Scope 'Saved snapshot not verified'
}
$originalFile = Join-Path $SnapshotDirectory 'baseline.private.json'
try { $baseline = Get-Content -LiteralPath $originalFile -Raw | ConvertFrom-Json }
catch { Stop-Scope 'Saved snapshot cannot be parsed' }
$states = @{}
foreach ($entry in @($baseline.package_states.PSObject.Properties)) {
    $states[$entry.Name] = [string]$entry.Value
}
# Validate ADB before issuing any query, and refuse multiple devices.
if ([IO.Path]::IsPathRooted($AdbPath) -and (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    $script:AdbExecutable=(Resolve-Path -LiteralPath $AdbPath).Path
} else {
    $found=Get-Command -Name $AdbPath -ErrorAction SilentlyContinue
    if ($null -eq $found -or $found.CommandType -notin @('Application','ExternalScript')) {
        Stop-Scope 'ADB executable unavailable'
    }
    $script:AdbExecutable=$found.Source
}
$deviceReply=Invoke-Read -Arguments @('devices')
$deviceStates=@()
foreach ($line in ($deviceReply -split '\r?\n')) {
    if ($line -match '^\s*\S+\s+(device|offline|unauthorized|recovery|sideload|bootloader)(?:\s|$)') {
        $deviceStates += $Matches[1]
    }
}
if ($deviceStates.Count -ne 1 -or $deviceStates[0] -ne 'device') {
    Stop-Scope 'Exactly one authorized projector required'
}
$props=[ordered]@{}
foreach ($p in @('ro.product.model','ro.product.device','ro.build.version.release',
                 'ro.build.version.sdk','ro.build.display.id')) {
    $v=Invoke-Read -Arguments @('shell','getprop',$p)
    if ($v.Length -gt 110 -or $v -notmatch '^[A-Za-z0-9._/()+ -]+$') {
        Stop-Scope 'Unexpected device property'
    }
    $props[$p]=$v
}
if ($props['ro.product.model'] -cne 'MiProjM05' -or
    $props['ro.product.device'] -cne 'eva' -or
    $props['ro.build.version.release'] -cne '9' -or
    $props['ro.build.version.sdk'] -cne '28' -or
    $props['ro.build.display.id'] -cne 'PQ3B.190705.003.4185') {
    Stop-Scope 'Firmware differs from audited baseline'
}
$userReply=Invoke-Read -Arguments @('shell','am','get-current-user')
if ($userReply -cnotmatch '^\d{1,5}$') { Stop-Scope 'Cannot determine active Android user' }
$currentUser=[int]$userReply
if ($currentUser -ne 0) {
    Stop-Scope 'Active Android user is not user 0; request separate multi-user audit'
}
$implicit=Read-Partition -UserFlag @()
$explicit=Read-Partition -UserFlag @('--user','0')

$protected=@(
  'com.google.android.tvlauncher','com.android.tv.settings',
  'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
  'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
  'com.droidlogic','com.droidlogic.tvinput','com.android.camera2'
)
foreach($name in $protected) {
    if (-not $explicit.enabled.Contains($name)) {
        Stop-Scope 'Protected factory package missing or disabled for user 0'
    }
}
$scopeChanges=0
foreach($name in $implicit.all) {
    if ((State-At $implicit $name) -cne (State-At $explicit $name)) { $scopeChanges++ }
}
foreach($name in $explicit.all) {
    if (-not $implicit.all.Contains($name)) { $scopeChanges++ }
}
$baselineChanges=0
foreach($name in @($states.Keys)) {
    if ((State-At $explicit $name) -cne $states[$name]) { $baselineChanges++ }
}
foreach($name in $explicit.all) {
    if (-not $states.ContainsKey($name)) { $baselineChanges++ }
}
$agree=($scopeChanges -eq 0 -and $baselineChanges -eq 0)
[pscustomobject]@{
    status=if ($agree) { 'user0-matches-baseline' } else { 'review-required' }
    mode='read-only-user0-scope-audit'
    active_android_user=0
    snapshot_sha256='match'
    implicit_packages=$implicit.all.Count
    explicit_user0_packages=$explicit.all.Count
    explicit_user0_disabled=$explicit.disabled.Count
    snapshot_packages=$states.Count
    implicit_vs_explicit_state_differences=$scopeChanges
    user0_vs_snapshot_differences=$baselineChanges
    device_writes=0
    home_switch_blocked=$true
    note='READ ONLY; does not change existing snapshot or prove real Android 9 rollback.'
} | ConvertTo-Json -Depth 5
