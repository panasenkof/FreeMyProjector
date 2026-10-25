#requires -Version 5.1
<#
.SYNOPSIS
  P-04H: discover OEM Bluetooth / remote-pairing entrypoints READ ONLY.
.DESCRIPTION
  Verifies P-04B snapshot offline, enforces exact MiProjM05/eva Android 9 build,
  uses only ADB devices/getprop/current-user, package activity query and dumpsys
  of three known settings packages. Outputs only sanitized component candidates.
  Never launches Activities, changes settings, pairs devices or writes files.
.EXAMPLE
  .\tools\Find-ProjectorRemotePairing.ps1 -SnapshotDirectory $folder -AdbPath $adb
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SnapshotDirectory,
      [string]$AdbPath='adb')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Stop-Pairing([string]$Reason) {
    throw "P-04H read-only discovery STOPPED: $Reason. No projector changes."
}
function Call-Adb([string[]]$A,[switch]$AllowEmpty) {
    try {
        $global:LASTEXITCODE=0
        $v=& $script:AdbExecutable @A 2>&1
        if($LASTEXITCODE -ne 0) { Stop-Pairing 'ADB read command failed' }
        $s=(@($v) -join [Environment]::NewLine).Trim()
        if(-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($s)) {Stop-Pairing 'Empty ADB response'}
        return [string]$s
    } catch { Stop-Pairing 'ADB read failed' }
}
function Valid-Component([string]$Value) {
    return $Value -cmatch '^(?:com\.android\.tv\.settings|com\.fengmi\.fmsettings|com\.formovie\.gsettings)/[A-Za-z0-9_.$]+$' -and $Value.Length -le 220
}
function Candidates($Text) {
    $set=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach($line in ($Text -split '\r?\n')) {
        # Strictly accept a listed OEM package and syntactically valid component.
        foreach($m in [regex]::Matches($line,'(?:com\.android\.tv\.settings|com\.fengmi\.fmsettings|com\.formovie\.gsettings)/[A-Za-z0-9_.$]+')) {
            $name=$m.Value
            if ((Valid-Component $name) -and $set.Count -lt 50) { [void]$set.Add($name) }
        }
    }
    return @($set | Sort-Object)
}
$verifier=Join-Path $PSScriptRoot 'Compare-ProjectorBaseline.ps1'
if (-not (Test-Path -LiteralPath $verifier -PathType Leaf)) {Stop-Pairing 'Baseline verifier missing'}
$v=(& $verifier -SnapshotDirectory $SnapshotDirectory -VerifyOnly) | ConvertFrom-Json
if ($v.status -cne 'verified' -or $v.sha256 -cne 'match' -or [int]$v.device_writes -ne 0) {
    Stop-Pairing 'Snapshot checksum did not verify'
}
if([IO.Path]::IsPathRooted($AdbPath) -and (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    $script:AdbExecutable=(Resolve-Path -LiteralPath $AdbPath).Path
} else {
    $ex=Get-Command -Name $AdbPath -ErrorAction SilentlyContinue
    if($null -eq $ex -or $ex.CommandType -notin @('Application','ExternalScript')) {Stop-Pairing 'ADB unavailable'}
    $script:AdbExecutable=$ex.Source
}
$devices=Call-Adb -A @('devices')
$found=@($devices -split '\r?\n' | Where-Object { $_ -match '^\s*\S+\s+(device|offline|unauthorized|recovery|sideload|bootloader)(?:\s|$)' })
if ($found.Count -ne 1 -or $found[0] -notmatch '\sdevice\s*$') {Stop-Pairing 'Exactly one authorized projector required'}
$required=[ordered]@{
    'ro.product.model'='MiProjM05'
    'ro.product.device'='eva'
    'ro.build.version.release'='9'
    'ro.build.version.sdk'='28'
    'ro.build.display.id'='PQ3B.190705.003.4185'
}
foreach($k in $required.Keys) {
    $p=Call-Adb -A @('shell','getprop',$k)
    if($p -cne $required[$k]) {Stop-Pairing 'Firmware differs from audited projector'}
}
$user=Call-Adb -A @('shell','am','get-current-user')
if($user -cne '0') {Stop-Pairing 'Android user is not 0'}
$standardAction='android.settings.BLUETOOTH_SETTINGS'
$resolved=Call-Adb -A @('shell','cmd','package','resolve-activity','--brief','-a',$standardAction) -AllowEmpty
$standard=@(Candidates $resolved | Sort-Object)
# This query is read-only; a failure is conservatively treated as unresolved.
$listed=Call-Adb -A @('shell','cmd','package','query-activities','--brief','-a',$standardAction) -AllowEmpty
$queried=@(Candidates $listed | Sort-Object)
$oem=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($pkg in @('com.android.tv.settings','com.fengmi.fmsettings','com.formovie.gsettings')) {
    $dump=Call-Adb -A @('shell','dumpsys','package',$pkg) -AllowEmpty
    foreach($name in (Candidates $dump)) {
        if ($name -match '(?i)(bluetooth|accessor|remote|pair|device.*settings)') { [void]$oem.Add($name) }
    }
}
$all=@($oem | Sort-Object)
[pscustomobject]@{
    status=if($all.Count -gt 0 -or $standard.Count -gt 0) { 'candidates-found-not-validated' } else { 'no-safe-entrypoint-confirmed' }
    mode='read-only-oem-pairing-discovery'
    model='MiProjM05'
    firmware_match=$true
    user=0
    standard_bluetooth_action=$standardAction
    resolved_bluetooth_components=@($standard)
    matching_bluetooth_components=@($queried)
    oem_pairing_activity_candidates=@($all)
    vendor_activity_launch_verified=$false
    device_writes=0
    home_switch_blocked=$true
    note='Candidates only. Not proof of exported permissions or actual pairing screen. No Activity launched.'
} | ConvertTo-Json -Depth 6
