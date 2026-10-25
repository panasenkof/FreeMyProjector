#requires -Version 5.1
# All comparisons below use an offline fake ADB and disposable JSON data.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$save=Join-Path $root 'tools/Save-ProjectorBaseline.ps1'
$compare=Join-Path $root 'tools/Compare-ProjectorBaseline.ps1'
$fake=Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmp-diff-tests-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)

function Assert([bool]$Condition,[string]$Reason) { if (-not $Condition) { throw "FAILED: $Reason" } }
function Check-AllowedCalls([string]$Path) {
    $calls=@(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    Assert ($calls.Count -gt 0) 'No mock ADB calls recorded'
    foreach($call in $calls) {
        $allowed=($call -eq 'devices') -or
            ($call -match '^shell getprop ro\.(product\.(model|device)|build\.(version\.(release|sdk)|display\.id))$') -or
            ($call -match '^shell cmd package (resolve-activity|query-activities) --brief -a android.intent.action.MAIN -c android.intent.category.HOME$') -or
            ($call -match '^shell pm list packages( -(e|d))?$')
        Assert $allowed "Forbidden ADB invocation: $call"
    }
}
function Invoke-Case([string]$Scenario,[bool]$Succeeds) {
    $env:FMP_MOCK_CASE=$Scenario
    $env:FMP_MOCK_LOG=Join-Path $temp ($Scenario+'.calls.txt')
    $before=(Get-FileHash -LiteralPath $script:jsonFile -Algorithm SHA256).Hash
    $foldersBefore=@(Get-ChildItem -LiteralPath $temp -Directory).Count
    $reply=$null
    $err=''
    try {
        $reply= (& $script:compare -SnapshotDirectory $script:folder -AdbPath $fake) | ConvertFrom-Json
    } catch { $err=$_.Exception.Message }
    Check-AllowedCalls $env:FMP_MOCK_LOG
    Assert ((Get-FileHash -LiteralPath $script:jsonFile -Algorithm SHA256).Hash -eq $before) 'Snapshot changed during comparison'
    Assert (@(Get-ChildItem -LiteralPath $temp -Directory).Count -eq $foldersBefore) 'Preview must not write a new folder'
    if ($Succeeds) {
        Assert ($err -eq '') "Scenario $Scenario unexpectedly failed: $err"
        Assert ($reply.snapshot_sha256 -eq 'match') 'SHA status not reported'
        Assert ($reply.home_switch_blocked -eq $true) 'HOME gate must stay closed'
        Assert ($reply.device_writes -eq 0) 'No device writes are allowed'
        Assert ($reply.firmware_match -eq $true) 'Firmware check missing'
        Assert ($reply.mode -eq 'read-only-difference-preview') 'Mode not labelled'
        Assert (-not (($reply | ConvertTo-Json -Depth 10) -match 'private-serial|192\.168')) 'Sensitive data leaked'
    } else {
        Assert ($err -match 'P-04B comparison STOPPED:') "Unsafe failure: $err"
        Assert ($null -eq $reply) 'Failure cannot return a viable recovery preview'
    }
    Write-Host "PASS: $Scenario"
    return $reply
}
try {
    $env:FMP_MOCK_CASE='connected'
    $env:FMP_MOCK_LOG=Join-Path $temp 'baseline.calls.txt'
    $saved= (& $save -AdbPath $fake -OutputDirectory $temp) | ConvertFrom-Json
    Assert ($saved.status -eq 'saved') 'Fake baseline creation failed'
    $script:folder=Join-Path $temp $saved.record_name
    $script:jsonFile=Join-Path $script:folder 'baseline.private.json'
    $originalHash=(Get-FileHash -LiteralPath $script:jsonFile -Algorithm SHA256).Hash

    # Offline checksum verification may not contact ADB at all.
    $env:FMP_MOCK_LOG=Join-Path $temp 'verify-only.calls.txt'
    $offline=(& $compare -SnapshotDirectory $script:folder -VerifyOnly -AdbPath (Join-Path $temp 'missing-adb.exe')) | ConvertFrom-Json
    Assert ($offline.status -eq 'verified') 'Offline checksum check failed'
    Assert ($offline.device_access -eq 'none') 'Offline mode must not access device'
    Assert ($offline.device_writes -eq 0) 'Offline mode cannot write device'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Offline mode unexpectedly contacted ADB'
    Write-Host 'PASS: verify-only without adb'

    $same=Invoke-Case connected $true
    Assert ($same.status -eq 'matches-baseline') 'Same state should be equal'
    Assert ($same.packages.changed_state.Count -eq 0) 'No package states should differ'

    $state=Invoke-Case current-state-changed $true
    Assert ($state.status -eq 'review-required') 'Disabled-state drift not reported'
    Assert ($state.packages.changed_state.Count -eq 1) 'Expected one state change'
    Assert ($state.packages.changed_state[0].package -eq 'com.example.otherapp') 'Incorrect package drift'
    Assert ($state.packages.changed_state[0].baseline -eq 'disabled') 'Original disabled state lost'
    Assert ($state.packages.changed_state[0].current -eq 'enabled') 'Current state not reported'

    $homePreview=Invoke-Case current-home-other $true
    Assert ($homePreview.status -eq 'review-required') 'Changed HOME not reported'
    Assert ($homePreview.home.differs -eq $true) 'HOME difference flag missing'
    Assert ($homePreview.home.baseline -eq 'com.google.android.tvlauncher/.MainActivity') 'Original HOME changed'

    $extra=Invoke-Case current-extra-app $true
    Assert ($extra.packages.new_since_baseline.Count -eq 1) 'New app not shown'
    Assert ($extra.packages.new_since_baseline[0] -eq 'com.example.newapp') 'Wrong new package'

    $missing=Invoke-Case current-removed-app $true
    Assert ($missing.packages.absent_from_device.Count -eq 1) 'Missing app not reported'
    Assert ($missing.packages.absent_from_device[0] -eq 'com.example.otherapp') 'Wrong missing package'

    foreach($bad in @('unauthorized','multiple','current-wrong-firmware','current-fallback-home',
        'protected-disabled','missing-claimant','query-error','inconsistent','malformed',
        'current-home-chooser')) {
        [void](Invoke-Case $bad $false)
    }

    # SHA tampering must STOP before invoking even the fake ADB.
    $badFolder=Join-Path $temp 'corrupt-snapshot'
    [void](New-Item -ItemType Directory -Path $badFolder)
    Copy-Item -LiteralPath $script:jsonFile -Destination (Join-Path $badFolder 'baseline.private.json')
    Copy-Item -LiteralPath (Join-Path $script:folder 'SHA256SUMS.txt') -Destination (Join-Path $badFolder 'SHA256SUMS.txt')
    Add-Content -LiteralPath (Join-Path $badFolder 'baseline.private.json') -Value ' '
    $env:FMP_MOCK_LOG=Join-Path $temp 'tampered.calls.txt'
    $err=''
    try { & $compare -SnapshotDirectory $badFolder -AdbPath $fake | Out-Null }
    catch { $err=$_.Exception.Message }
    Assert ($err -match 'SHA256 mismatch') 'Tampering must be rejected'
    Assert (-not (Test-Path -LiteralPath $env:FMP_MOCK_LOG)) 'Corrupt snapshot was allowed to contact ADB'
    Assert ((Get-FileHash -LiteralPath $script:jsonFile -Algorithm SHA256).Hash -eq $originalHash) 'Original snapshot modified'
    Write-Host 'PASS: tampered snapshot refused before ADB'
    Write-Host 'All offline P-04B comparison tests passed.'
} finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
