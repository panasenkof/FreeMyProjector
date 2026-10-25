#requires -Version 5.1
# P-04E: Android 9 user-0 package scope tests, mock ADB only.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$save=Join-Path $repo 'tools/Save-ProjectorBaseline.ps1'
$scope=Join-Path $repo 'tools/Test-ProjectorUser0Scope.ps1'
$fake=Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmp-scope-tests-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
function Assert([bool]$Ok,[string]$Text) { if(-not $Ok){throw "FAILED: $Text"} }
function Check-ReadOnly([string]$Log) {
    foreach($cmd in @(Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue)) {
        $allowed=($cmd -eq 'devices') -or
            ($cmd -eq 'shell am get-current-user') -or
            ($cmd -match '^shell getprop ro\.(product\.(model|device)|build\.(version\.(release|sdk)|display\.id))$') -or
            ($cmd -match '^shell pm list packages( -(d|e))?( --user 0)?$')
        Assert $allowed "Unexpected ADB action: $cmd"
    }
}
function Run-Case([string]$Name,[string]$Expected,[bool]$ShouldPass) {
    $env:FMP_MOCK_CASE=$Name
    $env:FMP_MOCK_LOG=Join-Path $temp ($Name+'.calls.txt')
    $err=''
    $answer=$null
    $before=(Get-FileHash -LiteralPath $script:original -Algorithm SHA256).Hash
    try { $answer=(& $script:scope -SnapshotDirectory $script:folder -AdbPath $fake) | ConvertFrom-Json }
    catch { $err=$_.Exception.Message }
    Assert ((Get-FileHash -LiteralPath $script:original -Algorithm SHA256).Hash -eq $before) 'Snapshot was modified'
    Check-ReadOnly $env:FMP_MOCK_LOG
    if($ShouldPass) {
        Assert ($err -eq '') "Unexpected error in $Name : $err"
        Assert ($answer.status -eq $Expected) "Wrong status in $Name"
        Assert ($answer.device_writes -eq 0 -and $answer.home_switch_blocked -eq $true) 'Device safety flags missing'
        Assert ($answer.active_android_user -eq 0) 'User 0 not verified'
        Assert ($answer.snapshot_sha256 -eq 'match') 'Snapshot checksum not verified'
        if($Expected -eq 'user0-matches-baseline') {
            Assert ($answer.implicit_vs_explicit_state_differences -eq 0) 'Implicit vs user0 unexpectedly differs'
            Assert ($answer.user0_vs_snapshot_differences -eq 0) 'User0 vs baseline unexpectedly differs'
        }
    } else {
        Assert ($err -match 'P-04E read-only scope STOPPED') "Expected fail-closed in $Name but got: $err"
        Assert ($null -eq $answer) 'Unsafe case returned usable result'
    }
    Write-Host "PASS: $Name"
}
try {
    $env:FMP_MOCK_CASE='connected'
    $env:FMP_MOCK_LOG=Join-Path $temp 'baseline-setup.calls.txt'
    $generated=(& $save -AdbPath $fake -OutputDirectory $temp) | ConvertFrom-Json
    Assert ($generated.status -eq 'saved') 'Failed to generate safe local mock baseline'
    $script:folder=Join-Path $temp $generated.record_name
    $script:original=Join-Path $script:folder 'baseline.private.json'
    Run-Case connected 'user0-matches-baseline' $true
    Run-Case scope-user0-diff 'review-required' $true
    Run-Case scope-user0-unsupported '' $false
    Run-Case scope-user0-protected-disabled '' $false
    Run-Case scope-other-user '' $false
    Run-Case unauthorized '' $false
    Run-Case multiple '' $false
    Run-Case wrong-firmware '' $false

    # Broken snapshot must not even invoke a mock ADB connection.
    $broken=Join-Path $temp 'broken-baseline'
    [void](New-Item -ItemType Directory -Path $broken)
    Copy-Item -LiteralPath $script:original -Destination (Join-Path $broken 'baseline.private.json')
    Copy-Item -LiteralPath (Join-Path $script:folder 'SHA256SUMS.txt') -Destination (Join-Path $broken 'SHA256SUMS.txt')
    Add-Content -LiteralPath (Join-Path $broken 'baseline.private.json') -Value ' '
    $env:FMP_MOCK_LOG=Join-Path $temp 'tampered.calls.txt'
    $err=''
    try { & $scope -SnapshotDirectory $broken -AdbPath $fake | Out-Null }
    catch { $err=$_.Exception.Message }
    Assert ($err -match 'SHA256 mismatch') 'Tampered snapshot must be refused'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Tampered snapshot contacted device'
    Write-Host 'PASS: SHA tamper prevented all ADB operations'
    Write-Host 'All P-04E read-only user 0 scope tests passed. No real projector accessed.'
}
finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
