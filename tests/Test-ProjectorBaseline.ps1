#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'tools/Save-ProjectorBaseline.ps1'
$fake = Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('fmp-p04b-tests-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
function Check([bool]$Good,[string]$Why) { if (-not $Good) { throw "FAILED: $Why" } }
function Test-Case([string]$Scenario,[bool]$ExpectedSuccess) {
    $env:FMP_MOCK_CASE = $Scenario
    $env:FMP_MOCK_LOG = Join-Path $tmp ($Scenario+'.calls.txt')
    $before = @(Get-ChildItem -LiteralPath $tmp -Directory).Count
    $errorText = ''
    $result = $null
    try {
        $response = & $script -AdbPath $fake -OutputDirectory $tmp
        if ($ExpectedSuccess) { $result = $response | ConvertFrom-Json }
        else { throw 'Expected failure but succeeded' }
    }
    catch { $errorText = $_.Exception.Message }
    if ($ExpectedSuccess -and $errorText -ne '') { throw "Baseline unexpectedly failed in $Scenario : $errorText" }
    Check (Test-Path -LiteralPath $env:FMP_MOCK_LOG) "ADB was never invoked in $Scenario : $errorText"
    $calls = @(Get-Content -LiteralPath $env:FMP_MOCK_LOG -ErrorAction SilentlyContinue | Where-Object { $_ -ne $null })
    Check ($calls.Count -gt 0) 'No ADB queries logged'
    foreach ($call in $calls) {
        $ok = $call -eq 'devices' -or
            $call -match '^shell getprop ro\.(product\.(model|device)|build\.(version\.(release|sdk)|display\.id))$' -or
            $call -match '^shell cmd package (resolve-activity|query-activities) --brief -a android.intent.action.MAIN -c android.intent.category.HOME$' -or
            $call -match '^shell pm list packages( -(e|d))?$'
        Check $ok "Prohibited command: $call"
    }
    $after = @(Get-ChildItem -LiteralPath $tmp -Directory).Count
    if ($ExpectedSuccess) {
        Check ($errorText -eq '') "Unexpected failure for $Scenario : $errorText"
        Check ($result.status -eq 'saved') 'Snapshot not saved'
        Check ($after -eq $before+1) 'Expected exactly one directory'
        $folder = Join-Path $tmp $result.record_name
        $jsonFile = Join-Path $folder 'baseline.private.json'
        $json = Get-Content -LiteralPath $jsonFile -Raw
        $data = $json | ConvertFrom-Json
        Check ($data.firmware.build -eq 'PQ3B.190705.003.4185') 'Wrong firmware'
        Check ($data.home.resolved -eq 'com.google.android.tvlauncher/.MainActivity') 'Wrong HOME'
        Check ($data.package_states.'com.fengmi.projector.imaging' -eq 'enabled') 'Imaging state lost'
        Check (-not ($json -match 'private-serial|192\.168')) 'Sensitive data leaked to snapshot'
        $digest = (Get-FileHash -LiteralPath $jsonFile -Algorithm SHA256).Hash.ToLowerInvariant()
        $sum = Get-Content -LiteralPath (Join-Path $folder 'SHA256SUMS.txt') -Raw
        Check ($sum.Trim() -eq ($digest+'  baseline.private.json')) 'SHA256 mismatch'
        if ($Scenario -eq 'zero-disabled') {
            Check ($result.disabled_packages -eq 0) 'Zero disabled not accepted'
        } else {
            Check ($data.package_states.'com.example.otherapp' -eq 'disabled') 'Original disabled state lost'
        }
        Write-Host "PASS: $Scenario"
    } else {
        Check ($errorText -match 'P-04B baseline NOT saved') "Unsafe failure: $errorText"
        Check ($after -eq $before) 'Failed read must not create a baseline'
        Write-Host "PASS (fail-closed): $Scenario"
    }
}
try {
    Test-Case connected $true
    Test-Case zero-disabled $true
    foreach ($scenario in @(
        'unauthorized','multiple','wrong-firmware','wrong-home','missing-claimant',
        'query-error','protected-disabled','inconsistent','malformed'
    )) { Test-Case $scenario $false }
    $env:FMP_MOCK_LOG = Join-Path $tmp 'repo-output.calls.txt'
    $errorText = ''
    try { & $script -AdbPath $fake -OutputDirectory $root | Out-Null }
    catch { $errorText = $_.Exception.Message }
    Check ($errorText -match 'outside repository') 'Snapshot inside repo must be refused'
    Check (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'ADB queried with unsafe output path'
    Write-Host 'PASS: reject in-repository output before ADB'
    Write-Host 'All P-04B mock tests passed. No real projector used.'
}
finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
