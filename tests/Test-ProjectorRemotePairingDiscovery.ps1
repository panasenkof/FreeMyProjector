#requires -Version 5.1
# P-04H read-only remote pairing discovery tests: all ADB is fake.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$save=Join-Path $repo 'tools/Save-ProjectorBaseline.ps1'
$discover=Join-Path $repo 'tools/Find-ProjectorRemotePairing.ps1'
$mock=Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('fmp-pair-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
function Assert([bool]$OK,[string]$Message) { if(-not $OK){throw "FAILED: $Message"} }
try {
    $env:FMP_MOCK_CASE='zero-disabled'
    $env:FMP_MOCK_LOG=Join-Path $tmp 'setup-adb.txt'
    $result=(& $save -AdbPath $mock -OutputDirectory $tmp) | ConvertFrom-Json
    Assert ($result.status -eq 'saved') 'Snapshot mock save failed'
    $folder=Join-Path $tmp $result.record_name
    $snapshot=Join-Path $folder 'baseline.private.json'
    $before=(Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash
    foreach($case in @('zero-disabled','pairing-none')) {
        $env:FMP_MOCK_CASE=$case
        $env:FMP_MOCK_LOG=Join-Path $tmp ('adb-'+$case+'.txt')
        $response=(& $discover -SnapshotDirectory $folder -AdbPath $mock) | ConvertFrom-Json
        Assert ($response.mode -eq 'read-only-oem-pairing-discovery') 'Wrong mode'
        Assert ($response.device_writes -eq 0 -and $response.home_switch_blocked -eq $true) 'Writes must remain blocked'
        Assert ($response.vendor_activity_launch_verified -eq $false) 'Discovery must never claim actual launch'
        if($case -eq 'zero-disabled') {
            Assert ($response.status -eq 'candidates-found-not-validated') 'Failed to find synthetic candidates'
            Assert (@($response.oem_pairing_activity_candidates).Count -gt 0) 'No candidate OEM Activity'
            Assert (@($response.resolved_bluetooth_components).Count -eq 1) 'No standard intent resolution'
            Assert (-not (($response | ConvertTo-Json -Depth 10) -match 'private-secret|192\.168')) 'Private dumpsys data leaked'
        } else {
            Assert ($response.status -eq 'no-safe-entrypoint-confirmed') 'Unknown settings must fail closed'
        }
        foreach($cmd in @(Get-Content -LiteralPath $env:FMP_MOCK_LOG)) {
            $allow=($cmd -eq 'devices') -or ($cmd -eq 'shell am get-current-user') -or
                ($cmd -match '^shell getprop ro\.') -or
                ($cmd -match '^shell cmd package (resolve-activity|query-activities) --brief -a android\.settings\.BLUETOOTH_SETTINGS$') -or
                ($cmd -match '^shell dumpsys package (com\.android\.tv\.settings|com\.fengmi\.fmsettings|com\.formovie\.gsettings)$')
            Assert $allow "Unexpected ADB operation: $cmd"
        }
        Write-Host "PASS: $case sanitized discovery with fake ADB"
    }
    $env:FMP_MOCK_CASE='wrong-firmware'
    $env:FMP_MOCK_LOG=Join-Path $tmp 'wrong-adb.txt'
    $errorMessage=''
    try { & $discover -SnapshotDirectory $folder -AdbPath $mock | Out-Null }
    catch { $errorMessage=$_.Exception.Message }
    Assert ($errorMessage -match 'P-04H read-only discovery STOPPED') 'Wrong firmware must be rejected'

    $tampered=Join-Path $tmp 'bad'
    [void](New-Item -ItemType Directory -Path $tampered)
    Copy-Item -LiteralPath $snapshot -Destination (Join-Path $tampered 'baseline.private.json')
    Copy-Item -LiteralPath (Join-Path $folder 'SHA256SUMS.txt') -Destination (Join-Path $tampered 'SHA256SUMS.txt')
    Add-Content -LiteralPath (Join-Path $tampered 'baseline.private.json') -Value ' '
    $env:FMP_MOCK_LOG=Join-Path $tmp 'tamper-adb.txt'
    $errorMessage=''
    try { & $discover -SnapshotDirectory $tampered -AdbPath $mock | Out-Null }
    catch { $errorMessage=$_.Exception.Message }
    Assert ($errorMessage -match 'SHA256 mismatch') 'Damaged baseline must fail before ADB'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Tampered baseline contacted ADB'
    Assert ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -eq $before) 'Original baseline mutated'
    Write-Host 'All read-only OEM pairing discovery tests passed. No physical projector used.'
} finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
