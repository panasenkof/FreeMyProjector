#requires -Version 5.1
<#
.SYNOPSIS
  Collects a P-04B local, read-only baseline for Xiaomi MiProjM05/eva.
.DESCRIPTION
  Does NOT back up firmware, private app data, vendor partitions or calibration.
  Only reads ADB devices, getprop, package HOME queries and package lists.
  Refuses unknown firmware, ambiguous HOME and inconsistent package states.
  Saves only after all checks pass, in a NEW directory outside this repository.
.EXAMPLE
  .\tools\Save-ProjectorBaseline.ps1 -AdbPath $adb -OutputDirectory "$env:USERPROFILE\Documents"
#>
[CmdletBinding()]
param(
    [string]$AdbPath = 'adb',
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Why) { throw "P-04B baseline NOT saved: $Why. Projector settings were not modified." }

function Read-Adb {
    param([string[]]$Arguments, [switch]$AllowEmpty)
    try {
        if ($null -eq $Arguments -or $Arguments.Count -lt 1) { Fail 'Empty ADB argument list' }
        $global:LASTEXITCODE = 0
        $raw = & $script:AdbExecutable @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { Fail 'ADB command failed' }
        $text = (@($raw) -join [Environment]::NewLine).Trim()
        if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($text)) { Fail 'ADB returned empty result' }
        return [string]$text
    }
    catch {
        # Never print raw stderr/stdout: it may include serials or IPs.
        Fail 'ADB read failed'
    }
}
function Read-Property([string]$Key) {
    $v = Read-Adb -Arguments @('shell','getprop',$Key)
    if ($v.Length -gt 110 -or $v -notmatch '^[A-Za-z0-9._/()+ -]+$') { Fail 'Invalid device property' }
    return $v
}
function Read-Packages {
    param([string[]]$Query, [switch]$AllowEmpty)
    $output = Read-Adb -Arguments $Query -AllowEmpty:$AllowEmpty
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($output)) {
        if (-not $AllowEmpty) { Fail 'Missing package list' }
        return ,$set
    }
    foreach ($line in ($output -split '\r?\n')) {
        if ($line -cnotmatch '^package:(android|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)$') {
            Fail 'Invalid package list entry'
        }
        if (-not $set.Add($Matches[1])) { Fail 'Duplicate package name' }
    }
    if (-not $AllowEmpty -and $set.Count -lt 15) { Fail 'Package inventory too small' }
    return ,$set
}
function Sorted($Items) { return @($Items | Sort-Object) }

# Validate output location before connecting to any device.
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { Fail 'Choose an existing output directory' }
$dest = (Resolve-Path -LiteralPath $OutputDirectory).Path.TrimEnd([char[]]@('\','/'))
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path.TrimEnd([char[]]@('\','/'))
$comparison = [StringComparison]::OrdinalIgnoreCase
if ($dest.Equals($repo,$comparison) -or
    $dest.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,$comparison) -or
    $dest.StartsWith($repo+[IO.Path]::AltDirectorySeparatorChar,$comparison)) {
    Fail 'Output must be outside repository'
}
if ([IO.Path]::IsPathRooted($AdbPath) -and (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    $script:AdbExecutable = (Resolve-Path -LiteralPath $AdbPath).Path
}
else {
    $found = Get-Command -Name $AdbPath -ErrorAction SilentlyContinue
    if ($null -eq $found -or $found.CommandType -notin @('Application','ExternalScript')) { Fail 'ADB executable unavailable' }
    $script:AdbExecutable = $found.Source
}

$rawDevices = Read-Adb -Arguments @('devices')
$states = @()
foreach ($line in ($rawDevices -split '\r?\n')) {
    if ($line -match '^\s*\S+\s+(device|unauthorized|offline|recovery|sideload|bootloader)(?:\s|$)') {
        $states += $Matches[1]
    }
}
if ($states.Count -ne 1 -or $states[0] -ne 'device') { Fail 'Exactly one authorized online projector required' }

$model = Read-Property 'ro.product.model'
$device = Read-Property 'ro.product.device'
$android = Read-Property 'ro.build.version.release'
$sdk = Read-Property 'ro.build.version.sdk'
$build = Read-Property 'ro.build.display.id'
if ($model -cne 'MiProjM05' -or $device -cne 'eva' -or $android -ne '9' -or $sdk -ne '28' -or
    $build -cne 'PQ3B.190705.003.4185') { Fail 'Unexpected model or firmware; audit again first' }

$homeText = Read-Adb -Arguments @('shell','cmd','package','resolve-activity','--brief',
    '-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$homeCandidates = @($homeText -split '\r?\n' | Where-Object { $_ -cmatch '^[A-Za-z][\w.]*/[\w.$]+$' })
if ($homeCandidates.Count -ne 1 -or $homeCandidates[0] -cne 'com.google.android.tvlauncher/.MainActivity') {
    Fail 'Stock HOME not resolved unambiguously'
}
$claimsText = Read-Adb -Arguments @('shell','cmd','package','query-activities','--brief',
    '-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$claimants = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($line in ($claimsText -split '\r?\n')) {
    $line = $line.Trim()
    if ($line -cmatch '^[A-Za-z][\w.]*/[\w.$]+$') { [void]$claimants.Add($line) }
}
if (-not $claimants.Contains('com.google.android.tvlauncher/.MainActivity')) {
    Fail 'Factory HOME absent from HOME claimant query'
}

$all = Read-Packages -Query @('shell','pm','list','packages')
$disabled = Read-Packages -Query @('shell','pm','list','packages','-d') -AllowEmpty
$enabled = Read-Packages -Query @('shell','pm','list','packages','-e')
foreach ($name in $disabled) {
    if (-not $all.Contains($name) -or $enabled.Contains($name)) { Fail 'Inconsistent disabled packages' }
}
foreach ($name in $enabled) {
    if (-not $all.Contains($name)) { Fail 'Inconsistent enabled packages' }
}
if ($all.Count -ne ($enabled.Count + $disabled.Count)) { Fail 'Package states do not partition installed list' }
$mustKeep = @(
    'com.google.android.tvlauncher', 'com.android.tv.settings',
    'com.fengmi.projector.imaging', 'com.fengmi.fmsettings', 'com.fengmi.platform',
    'com.formovie.fmutils', 'com.formovie.gsettings', 'com.formovie.launchboard',
    'com.droidlogic', 'com.droidlogic.tvinput', 'com.android.camera2'
)
foreach ($name in $mustKeep) {
    if (-not $enabled.Contains($name)) { Fail 'Protected factory package missing or disabled' }
}

$packageStates = [ordered]@{}
foreach ($name in (Sorted $all)) {
    $packageStates[$name] = if ($disabled.Contains($name)) { 'disabled' } else { 'enabled' }
}
$record = [ordered]@{
    schema_version = 1
    status = 'read-only-baseline'
    captured_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    firmware = [ordered]@{ model=$model; device=$device; android=$android; sdk=[int]$sdk; build=$build }
    home = [ordered]@{ resolved=$homeCandidates[0]; claimants=(Sorted $claimants) }
    package_states = $packageStates
    limitations = @(
        'NOT firmware, /data, vendor or calibration backup',
        'Package enabled/disabled states only, not individual Android components',
        'Pairing, remote buttons and picture settings require independent manual evidence',
        'HOME claimant enumeration does not prove HOME recoverability',
        'No device settings changed'
    )
}
# Generate a fresh folder ONLY after all required, read-only checks pass.
$basename = 'MiProjM05-baseline-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' +
    [guid]::NewGuid().ToString('N').Substring(0,10)
$folder = Join-Path $dest $basename
if (Test-Path -LiteralPath $folder) { Fail 'Backup path already exists' }
[void](New-Item -ItemType Directory -Path $folder -ErrorAction Stop)
$stage = 'create-json'
try {
    $path = Join-Path $folder 'baseline.private.json'
    $json = ConvertTo-Json -InputObject $record -Depth 8
    [IO.File]::WriteAllText($path,$json+[Environment]::NewLine,(New-Object System.Text.UTF8Encoding($false)))
    $stage = 'hash'
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $folder 'SHA256SUMS.txt'),
        ($hash+'  baseline.private.json'+[Environment]::NewLine),
        (New-Object System.Text.UTF8Encoding($false)))
    $stage = 'verify-json'
    $verified = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $stage = 'verify-integrity'
    if ($verified.home.resolved -cne $homeCandidates[0] -or
        $verified.package_states.PSObject.Properties.Count -ne $all.Count -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
        Fail 'Cannot verify written snapshot'
    }
}
catch {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    Fail ('Cannot write or verify the local backup [' + $stage + '/' + $_.Exception.GetType().Name + ']')
}
[pscustomobject]@{
    status = 'saved'
    record_name = $basename
    packages = $all.Count
    disabled_packages = $disabled.Count
    note = 'PRIVATE snapshot of package/HOME state only; NOT firmware backup. HOME switch BLOCKED.'
} | ConvertTo-Json -Depth 3
