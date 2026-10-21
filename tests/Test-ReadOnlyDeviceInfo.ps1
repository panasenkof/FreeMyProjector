#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $root 'tools/read-only-device-info.ps1'
$fakeAdb = Join-Path $PSScriptRoot 'fixtures/mock-adb.ps1'
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('freemyprojector-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempDir)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAILED: $Message" }
}

function Invoke-TestCase {
    param([string]$Scenario, [string]$Expected)
    $env:MOCK_ADB_SCENARIO = $Scenario
    $env:MOCK_ADB_LOG = Join-Path $tempDir "$Scenario.calls.txt"
    $json = & $scriptPath -AdbPath $fakeAdb
    $result = $json | ConvertFrom-Json
    Assert-True ($result.status -eq $Expected) "Case $Scenario expected $Expected, got $($result.status)"
    Assert-True (-not $json.Contains('unit-test-unique-serial-abcdef12345')) "$Scenario leaked device serial"
    Assert-True (-not $json.Contains('another-private-serial-9876')) "$Scenario leaked secondary device serial"
    Assert-True (-not $json.Contains('192.168.1.23')) "$Scenario leaked private IP"
    Assert-True (-not $json.Contains('private-user@')) "$Scenario leaked e-mail address"

    if (Test-Path -LiteralPath $env:MOCK_ADB_LOG) {
        foreach ($call in @(Get-Content -LiteralPath $env:MOCK_ADB_LOG)) {
            $allow = $call -eq 'devices' -or
                $call -match '^shell getprop ro\.(?:product\.(?:model|device)|build\.(?:version\.(?:release|sdk)|display\.id))$' -or
                $call -eq 'shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
            Assert-True $allow "Non read-only ADB invocation: $call"
        }
    }
    if ($Expected -ne 'connected') {
        Assert-True ($null -eq $result.fields.model) "$Scenario should not query model"
        $calls = @(Get-Content -LiteralPath $env:MOCK_ADB_LOG -ErrorAction SilentlyContinue)
        Assert-True ($calls.Count -eq 1) "$Scenario must only call adb devices"
    }
    Write-Host "PASS: $Scenario"
    return $result
}

try {
    $ok = Invoke-TestCase -Scenario 'connected' -Expected 'connected'
    Assert-True ($ok.fields.model -eq 'Mi Smart Compact Projector') 'Expected safe model'
    Assert-True ($ok.fields.android -eq '9') 'Expected Android version'
    Assert-True ($ok.fields.sdk -eq '28') 'Expected API version'
    Assert-True ($ok.fields.home_component -eq 'com.google.android.tvlauncher/.MainActivity') 'Expected HOME component'

    foreach ($case in @('unauthorized', 'offline', 'none', 'multiple', 'adb-error')) {
        $expected = if ($case -eq 'none') { 'no-device' } elseif ($case -eq 'multiple') { 'multiple-devices' } else { $case }
        [void](Invoke-TestCase -Scenario $case -Expected $expected)
    }
    $missing = Invoke-TestCase -Scenario 'missing-fields' -Expected 'connected'
    Assert-True ($null -eq $missing.fields.device) 'Missing getprop value should be null'
    Assert-True ($null -eq $missing.fields.home_component) 'Unsupported HOME query should be null'

    $sensitive = Invoke-TestCase -Scenario 'sensitive-values' -Expected 'connected'
    Assert-True ($null -eq $sensitive.fields.build) 'Sensitive build string must be suppressed'

    $reportPath = Join-Path $tempDir 'report.device-info.local.json'
    $env:MOCK_ADB_SCENARIO = 'connected'
    $env:MOCK_ADB_LOG = Join-Path $tempDir 'file-test.calls.txt'
    $console = & $scriptPath -AdbPath $fakeAdb -OutputPath $reportPath
    Assert-True (Test-Path -LiteralPath $reportPath) 'Explicit local output path was not created'
    Assert-True ((Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json).status -eq 'connected') 'Saved JSON not parseable'
    Assert-True ($console -match '"connected"') 'Console must still contain result'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'device-info.local.json'))) 'Unrequested output file created'

    $unknown = (& $scriptPath -AdbPath (Join-Path $tempDir 'adb-does-not-exist.exe')) | ConvertFrom-Json
    Assert-True ($unknown.status -eq 'adb-not-found') 'Expected missing adb status'
    Assert-True ($null -eq $unknown.fields.model) 'Missing adb may not fabricate data'
    Write-Host 'PASS: adb-not-found, explicit local output'
    Write-Host 'All read-only diagnostic tests passed.'
}
finally {
    Remove-Item Env:MOCK_ADB_SCENARIO -ErrorAction SilentlyContinue
    Remove-Item Env:MOCK_ADB_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
