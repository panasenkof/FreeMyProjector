#requires -Version 5.1
<#
.SYNOPSIS
  OFFLINE ONLY: simulate a proposed MiProjM05 Android 9 rollback from a saved baseline.
.DESCRIPTION
  Uses a private baseline and a fabricated/mock scenario containing a change journal.
  Never invokes adb, shell commands or Android APIs; never changes the projector,
  saved baseline, mock scenario or user files. No actual rollback capability exists.
.EXAMPLE
  .\tools\Invoke-ProjectorRollbackSimulation.ps1 -BaselineDirectory $baseline -ScenarioPath $mock
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselineDirectory,
    [Parameter(Mandatory = $true)][string]$ScenarioPath,
    [ValidateRange(0,1000)][int]$FailAtStep = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Stop-Sim([string]$Why) {
    throw "P-04D OFFLINE simulation REFUSED: $Why. No projector commands executed."
}
function Valid-Package([string]$Name) {
    return $Name -cmatch '^(?:android|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)$'
}
function Get-States($Object,[string]$Label) {
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { Stop-Sim "$Label package_states must be an object" }
    $result = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($entry in @($Object.PSObject.Properties)) {
        $name = [string]$entry.Name
        $state = [string]$entry.Value
        if (-not (Valid-Package $name) -or $state -cnotin @('enabled','disabled') -or
            $result.ContainsKey($name)) { Stop-Sim "$Label invalid package/state" }
        $result.Add($name,$state)
    }
    if ($result.Count -lt 15) { Stop-Sim "$Label package inventory too small" }
    return ,$result
}
# First validate original snapshot completely OFFLINE. Do not trust JSON without matching bytes.
if (-not (Test-Path -LiteralPath $BaselineDirectory -PathType Container)) { Stop-Sim 'Baseline folder missing' }
$folder = (Resolve-Path -LiteralPath $BaselineDirectory).Path
$originalFile = Join-Path $folder 'baseline.private.json'
$sumFile = Join-Path $folder 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $originalFile -PathType Leaf) -or
    -not (Test-Path -LiteralPath $sumFile -PathType Leaf)) { Stop-Sim 'Baseline checksum or JSON missing' }
$sum = @(Get-Content -LiteralPath $sumFile)
if ($sum.Count -ne 1) { Stop-Sim 'Invalid SHA256SUMS' }
if ($sum[0] -cmatch '^([0-9A-Fa-f]{64})  baseline\.private\.json$') {
    $expected = $Matches[1]
} else { Stop-Sim 'Invalid checksum format' }
if ((Get-FileHash -LiteralPath $originalFile -Algorithm SHA256).Hash -ine $expected) {
    Stop-Sim 'Baseline checksum changed'
}
try { $baseline = Get-Content -LiteralPath $originalFile -Raw | ConvertFrom-Json }
catch { Stop-Sim 'Invalid baseline JSON' }
if ($baseline.schema_version -ne 1 -or $baseline.status -cne 'read-only-baseline' -or
    $baseline.firmware.model -cne 'MiProjM05' -or $baseline.firmware.device -cne 'eva' -or
    [string]$baseline.firmware.android -cne '9' -or
    [string]$baseline.firmware.sdk -cne '28' -or
    $baseline.firmware.build -cne 'PQ3B.190705.003.4185' -or
    $baseline.home.resolved -cne 'com.google.android.tvlauncher/.MainActivity') {
    Stop-Sim 'Baseline is not audited MiProjM05/.4185 factory HOME'
}
$baseStates = Get-States $baseline.package_states 'Baseline'
$stockHome = 'com.google.android.tvlauncher/.MainActivity'
$proposedHome = 'com.fader.freemyprojector/io.freemytv.HomeActivity'
$protected = @(
    'com.google.android.tvlauncher','com.android.tv.settings',
    'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
    'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
    'com.droidlogic','com.droidlogic.tvinput','com.android.camera2'
)
foreach ($name in $protected) {
    if (-not $baseStates.ContainsKey($name) -or $baseStates[$name] -cne 'enabled') {
        Stop-Sim 'Protected OEM/factory package missing from baseline'
    }
}
# The scenario is a MOCK fixture. It is not read from a live device.
if (-not (Test-Path -LiteralPath $ScenarioPath -PathType Leaf)) { Stop-Sim 'Mock scenario missing' }
try { $scenario = Get-Content -LiteralPath $ScenarioPath -Raw | ConvertFrom-Json }
catch { Stop-Sim 'Malformed mock scenario JSON' }
if ($scenario.schema_version -ne 1 -or $scenario.kind -cne 'OFFLINE_MOCK_ONLY' -or
    $null -eq $scenario.mock_device -or $null -eq $scenario.journal) {
    Stop-Sim 'Explicit OFFLINE_MOCK_ONLY scenario required'
}
$device = $scenario.mock_device
if ($device.firmware.model -cne 'MiProjM05' -or $device.firmware.device -cne 'eva' -or
    [string]$device.firmware.android -cne '9' -or [string]$device.firmware.sdk -cne '28' -or
    $device.firmware.build -cne $baseline.firmware.build) {
    Stop-Sim 'Mock firmware does not match baseline'
}
$currentHome = [string]$device.home
if ($currentHome -match '(?i)FallbackHome|SetupWizard|RecoveryActivity' -or
    $currentHome -cnotin @($stockHome,$proposedHome)) {
    Stop-Sim 'Unexpected/fallback HOME in mock device'
}
if ($null -eq $device.home_claimants -or
    @($device.home_claimants | Where-Object { $_ -ceq $stockHome }).Count -ne 1) {
    Stop-Sim 'Original stock HOME not present in mock claimant list'
}
if ($scenario.journal.original_home -cne $stockHome -or
    $scenario.journal.selected_home -cnotin @($stockHome,$proposedHome)) {
    Stop-Sim 'Journal HOME is not an approved test candidate'
}
if ($currentHome -cnotin @($stockHome,[string]$scenario.journal.selected_home)) {
    Stop-Sim 'Current HOME is not explained by journal'
}
$currentStates = Get-States $device.package_states 'Mock'
foreach ($name in $baseStates.Keys) {
    if (-not $currentStates.ContainsKey($name)) {
        Stop-Sim 'Baseline package missing from mock: rollback cannot recreate APK'
    }
}
foreach ($name in $protected) {
    if ($currentStates[$name] -cne 'enabled') {
        Stop-Sim 'Mock protected OEM/factory package disabled'
    }
}
$journal = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$changes = @($scenario.journal.package_changes)
if ($changes.Count -gt 30) { Stop-Sim 'Journal change count exceeds conservative cap' }
foreach ($change in $changes) {
    if ($null -eq $change) { Stop-Sim 'Journal has null entry' }
    $name = [string]$change.package
    if (-not (Valid-Package $name) -or -not $baseStates.ContainsKey($name) -or
        $journal.ContainsKey($name) -or
        $name -in $protected -or
        $name -match '^(com\.fengmi\.|com\.formovie\.|cn\.formovie\.|com\.droidlogic\.|com\.droidlogic$)' -or
        $name -in @('android','com.google.android.tvlauncher','com.fader.freemyprojector')) {
        Stop-Sim 'Duplicate, unknown or OEM/protected package in journal'
    }
    if ($change.before -cnotin @('enabled','disabled') -or
        $change.after -cnotin @('enabled','disabled') -or
        $change.before -cne $baseStates[$name] -or $change.after -ceq $change.before) {
        Stop-Sim 'Journal does not correspond to original package state'
    }
    $journal.Add($name,[string]$change.after)
}
foreach ($name in $baseStates.Keys) {
    $actual = $currentStates[$name]
    if ($journal.ContainsKey($name)) {
        if ($actual -cnotin @($baseStates[$name],$journal[$name])) {
            Stop-Sim 'Mock current state cannot be explained by journal'
        }
    } elseif ($actual -cne $baseStates[$name]) {
        Stop-Sim 'Unlogged package state drift: cannot infer who modified it'
    }
}
# Compute a reversible plan in memory. No ADB command strings or operational handlers exist.
$planned = @()
if ($currentHome -cne $stockHome) {
    if ($scenario.journal.selected_home -cne $proposedHome) { Stop-Sim 'Unjournaled HOME switch' }
    if (-not $currentStates.ContainsKey('com.fader.freemyprojector') -or
        $currentStates['com.fader.freemyprojector'] -cne 'enabled') {
        Stop-Sim 'Simulated custom HOME app unavailable'
    }
    $planned += [pscustomobject]@{
        kind='restore-home'
        target=$stockHome
        explanation='OFFLINE plan only: original TV launcher must remain installed and enabled'
    }
}
foreach ($name in @($journal.Keys | Sort-Object)) {
    if ($currentStates[$name] -cne $baseStates[$name]) {
        $planned += [pscustomobject]@{
            kind='restore-package-state'
            package=$name
            target=$baseStates[$name]
            explanation='OFFLINE plan only: restore only a journalled mutation'
        }
    }
}
$mockHome = $currentHome
$mockStates = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
foreach ($name in $currentStates.Keys) { $mockStates.Add($name,$currentStates[$name]) }
$performed = 0
$failed = $false
foreach ($step in $planned) {
    if ($FailAtStep -gt 0 -and $performed+1 -eq $FailAtStep) {
        $failed = $true
        break
    }
    if ($step.kind -eq 'restore-home') {
        $mockHome = $stockHome
    } else {
        $mockStates[$step.package] = $step.target
    }
    $performed++
}
$verified = (-not $failed -and $mockHome -ceq $stockHome)
foreach ($name in $baseStates.Keys) {
    if ($mockStates[$name] -cne $baseStates[$name]) { $verified = $false; break }
}
[pscustomobject]@{
    status=if ($failed) { 'mock-failure-injected' } elseif ($verified) { 'mock-restored' } else { 'mock-verification-failed' }
    mode='OFFLINE_MOCK_ONLY'
    baseline_sha256='match'
    original_home=$stockHome
    initial_mock_home=$currentHome
    final_mock_home=$mockHome
    planned_actions=@($planned)
    mock_actions_completed=$performed
    mock_verification_passed=$verified
    physical_device_access='none'
    device_writes=0
    home_switch_blocked=$true
    note='SIMULATION ONLY. No real-device rollback, ADB commands, firmware restoration or HOME switch.'
} | ConvertTo-Json -Depth 8
