#requires -Version 5.1
# One-command owner snapshot test uses synthetic baseline and NEVER touches projector.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo=Split-Path -Parent $PSScriptRoot
$save=Join-Path $repo 'tools/Save-ProjectorBaseline.ps1'
$runner=Join-Path $repo 'tools/Test-ProjectorRollbackLocally.ps1'
$fake=Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmp-local-runner-tests-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
function Assert([bool]$Test,[string]$Why) { if(-not $Test){throw "FAILED: $Why"} }
try {
    $env:FMP_MOCK_CASE='connected'
    $env:FMP_MOCK_LOG=Join-Path $temp 'setup-only-adb.calls.txt'
    $saved=(& $save -AdbPath $fake -OutputDirectory $temp) | ConvertFrom-Json
    Assert ($saved.status -eq 'saved') 'Fake baseline not saved'
    $snapshot=Join-Path $temp $saved.record_name
    $original=Join-Path $snapshot 'baseline.private.json'
    $digest=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash

    # Make sure even the fake ADB is NOT invoked by the local simulation.
    $env:FMP_MOCK_LOG=Join-Path $temp 'unexpected-adb.calls.txt'
    $answer=(& $runner -SnapshotDirectory $snapshot) | ConvertFrom-Json
    Assert ($answer.status -eq 'passed') 'Local owner-snapshot simulator not successful'
    Assert ($answer.mode -eq 'OFFLINE_MOCK_ONLY') 'Wrong mode'
    Assert ($answer.original_snapshot_unchanged -eq $true) 'Snapshot must stay untouched'
    Assert ($answer.device_access -eq 'none' -and $answer.device_writes -eq 0) 'No real hardware access permitted'
    Assert ($answer.home_switch_blocked -eq $true) 'HOME switch must remain blocked'
    Assert ($answer.package_state_mock -eq 'executed-offline-only') 'Fixture should exercise package-state rollback'
    Assert ($answer.cases.Count -eq 5) 'Expected noop, HOME, error before HOME, HOME+package, error before package'
    Assert (@($answer.cases | Where-Object {$_.status -eq 'mock-restored'}).Count -eq 3) 'Expected three successful scenarios'
    Assert (@($answer.cases | Where-Object {$_.status -eq 'mock-failure-injected'}).Count -eq 2) 'Expected two failure scenarios'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Offline local test tried to use ADB'
    Assert ((Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -eq $digest) 'Original baseline hash changed'
    $parent=Split-Path -Parent $repo
    $leftover=@(Get-ChildItem -LiteralPath $parent -Directory -Filter 'fmp-p04d-local-mock-*' -ErrorAction SilentlyContinue)
    Assert ($leftover.Count -eq 0) 'Local runner left mock files in parent workspace'
    Write-Host 'PASS: locally simulated 5 scenarios with mock baseline, no ADB, no side effects'

    $corrupt=Join-Path $temp 'corrupted'
    [void](New-Item -ItemType Directory -Path $corrupt)
    Copy-Item -LiteralPath $original -Destination (Join-Path $corrupt 'baseline.private.json')
    Copy-Item -LiteralPath (Join-Path $snapshot 'SHA256SUMS.txt') -Destination (Join-Path $corrupt 'SHA256SUMS.txt')
    Add-Content -LiteralPath (Join-Path $corrupt 'baseline.private.json') -Value ' '
    $bad=''
    try { & $runner -SnapshotDirectory $corrupt | Out-Null }
    catch { $bad=$_.Exception.Message }
    Assert ($bad -match 'SHA256 mismatch') 'Corrupted snapshot should be rejected'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Corrupted snapshot attempted ADB'
    Write-Host 'PASS: bad SHA refused, no ADB'
    Write-Host 'All owner local rollback dry-run tests passed. No real projector used.'
}
finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
