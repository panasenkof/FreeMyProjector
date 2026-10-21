#requires -Version 5.1
<#
.SYNOPSIS
  Collects a minimal, privacy-preserving Android TV device report (read-only).
.DESCRIPTION
  Runs only 'adb devices', 'adb shell getprop <allowlisted-key>' and
  'adb shell cmd package resolve-activity ... HOME'. Never changes device
  settings, packages, Wi-Fi or the default launcher. Does not require root.
  Reports only allowlisted, validated fields, never device serials or ADB logs.
.PARAMETER AdbPath
  Path to adb.exe (or 'adb' available in PATH). Also accepts a test double.
.PARAMETER OutputPath
  OPTIONAL local JSON destination. Nothing is saved unless specified.
.EXAMPLE
  .\tools\read-only-device-info.ps1
.EXAMPLE
  .\tools\read-only-device-info.ps1 -OutputPath .\device-info.local.json
#>
[CmdletBinding()]
param(
    [string]$AdbPath = 'adb',
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AdbPath {
    param([string]$Candidate)
    if ([System.IO.Path]::IsPathRooted($Candidate) -and
        (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $Candidate).Path
    }
    $command = Get-Command -Name $Candidate -ErrorAction SilentlyContinue
    if ($null -eq $command) { return $null }
    if ($command.CommandType -notin @('Application', 'ExternalScript')) { return $null }
    return $command.Source
}

function Invoke-ReadOnlyAdb {
    param([string[]]$Arguments)
    # This is the ONLY place invoking adb. No untrusted input is used for commands.
    # Do not forward raw stdout/stderr to the user: it can contain unique IDs.
    try {
        $raw = & $script:AdbExecutable @Arguments 2>&1
        $exitVariable = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
        $exitCode = if ($null -ne $exitVariable) { [int]$exitVariable.Value } else { 0 }
        if ($exitCode -ne 0) { return @{ Success = $false; Text = '' } }
        return @{ Success = $true; Text = (@($raw) -join [Environment]::NewLine).Trim() }
    }
    catch {
        return @{ Success = $false; Text = '' }
    }
}

function Clean-Property {
    param([string]$Key, [string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $value = $Raw.Trim()
    # Reject multiline/control chars, network addresses, e-mail, or unexpectedly
    # formatted identifiers instead of trying to redact unknown firmware output.
    if ($value.Length -gt 100 -or $value -match '[\x00-\x1F\x7F]' -or
        $value -match '(?i)(?:\d{1,3}\.){3}\d{1,3}' -or
        $value -match '(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}' -or
        $value -match '[^\s@]+@[^\s@]+') { return $null }
    switch ($Key) {
        'model'      { if ($value -cmatch '^[\p{L}\p{N} ._()+/-]{1,100}$') { return $value } }
        'device'     { if ($value -cmatch '^[A-Za-z0-9._-]{1,80}$') { return $value } }
        'android'    { if ($value -match '^\d{1,2}(?:\.\d{1,3}){0,3}$') { return $value } }
        'sdk'        { if ($value -match '^\d{1,3}$') { return $value } }
        'build'      { if ($value -cmatch '^[A-Za-z0-9._/()+ :\-]{1,100}$') { return $value } }
    }
    return $null
}

$fields = [ordered]@{
    model = $null
    device = $null
    android = $null
    sdk = $null
    build = $null
    home_component = $null
}
$report = [ordered]@{
    schema_version = 1
    status = 'adb-not-found'
    source = 'on-device'
    fields = $fields
    note = 'No settings or packages were changed. Check report before sharing.'
}
$script:AdbExecutable = Resolve-AdbPath -Candidate $AdbPath

if ($null -ne $script:AdbExecutable) {
    $probe = Invoke-ReadOnlyAdb -Arguments @('devices')
    if (-not $probe.Success) {
        $report.status = 'adb-error'
    }
    else {
        $states = @()
        foreach ($line in ($probe.Text -split '\r?\n')) {
            # Parse only connection state. Device serials NEVER reach the report.
            if ($line -match '^\s*\S+\s+(device|offline|unauthorized)(?:\s|$)') {
                $states += $Matches[1]
            }
        }
        if ($states.Count -eq 0) {
            $report.status = 'no-device'
        }
        elseif ($states.Count -gt 1) {
            $report.status = 'multiple-devices'
        }
        elseif ($states[0] -eq 'unauthorized') {
            $report.status = 'unauthorized'
        }
        elseif ($states[0] -eq 'offline') {
            $report.status = 'offline'
        }
        elseif ($states[0] -eq 'device') {
            $report.status = 'connected'
            $properties = [ordered]@{
                model   = 'ro.product.model'
                device  = 'ro.product.device'
                android = 'ro.build.version.release'
                sdk     = 'ro.build.version.sdk'
                build   = 'ro.build.display.id'
            }
            foreach ($key in $properties.Keys) {
                $response = Invoke-ReadOnlyAdb -Arguments @('shell', 'getprop', $properties[$key])
                if ($response.Success) {
                    $fields[$key] = Clean-Property -Key $key -Raw $response.Text
                }
            }
            # Optional, read-only HOME resolution. Unsupported firmware => null.
            $home = Invoke-ReadOnlyAdb -Arguments @(
                'shell', 'cmd', 'package', 'resolve-activity', '--brief',
                '-a', 'android.intent.action.MAIN',
                '-c', 'android.intent.category.HOME'
            )
            if ($home.Success) {
                foreach ($line in ($home.Text -split '\r?\n')) {
                    $match = [regex]::Match($line.Trim(),
                        '^([A-Za-z][A-Za-z0-9_.]*/[A-Za-z0-9_.$]{1,100})$')
                    if ($match.Success -and $match.Groups[1].Value.Length -le 150) {
                        $fields.home_component = $match.Groups[1].Value
                    }
                }
            }
        }
    }
}

# A JSON document is emitted without unique device IDs, shell errors, or IPs.
$json = ConvertTo-Json -InputObject $report -Depth 4
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    [System.IO.File]::WriteAllText($fullPath, $json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false)))
}
Write-Output $json
