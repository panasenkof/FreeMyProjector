#requires -Version 5.1
# Offline P-04D regression tests: fake ADB is used ONLY to create disposable baseline.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$save=Join-Path $root 'tools/Save-ProjectorBaseline.ps1'
$sim=Join-Path $root 'tools/Invoke-ProjectorRollbackSimulation.ps1'
$fake=Join-Path $PSScriptRoot 'fixtures/mock-baseline-adb.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmp-p04d-tests-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "FAILED: $Message" } }
function Build-Mock([string]$Scenario,[switch]$CustomHome,[switch]$ChangedPackage,
                    [switch]$UnexpectedChange,[switch]$BadFirmware,[switch]$BadFallback,
                    [switch]$DisabledOem,[switch]$MissingPackage,[switch]$UnknownJournal) {
    $states=[ordered]@{}
    foreach($prop in $script:base.package_states.PSObject.Properties) {
        $states[$prop.Name]=[string]$prop.Value
    }
    $journalChanges=@()
    if($ChangedPackage) {
        $states['com.example.otherapp']='enabled'
        $journalChanges+=@{ package='com.example.otherapp'; before='disabled'; after='enabled' }
    }
    if($UnexpectedChange) { $states['com.example.otherapp']='enabled' }
    if($DisabledOem) { $states['com.fengmi.projector.imaging']='disabled' }
    if($MissingPackage) { $states.Remove('com.example.otherapp') }
    if($UnknownJournal) {
        $journalChanges+=@{ package='com.fengmi.projector.imaging'; before='enabled'; after='disabled' }
    }
    $firmware=@{
        model='MiProjM05'; device='eva'; android='9'; sdk=28;
        build=if($BadFirmware){'PQ3B.190705.003.2102'}else{'PQ3B.190705.003.4185'}
    }
    if($CustomHome) { $states['com.fader.freemyprojector']='enabled' }
    $mockHome=if($BadFallback){'com.android.tv.settings/.system.FallbackHome'}elseif($CustomHome){
        'com.fader.freemyprojector/io.freemytv.HomeActivity'
    }else{'com.google.android.tvlauncher/.MainActivity'}
    $mock=[ordered]@{
        schema_version=1
        kind='OFFLINE_MOCK_ONLY'
        mock_device=[ordered]@{
            firmware=$firmware
            home=$mockHome
            home_claimants=@('com.google.android.tvlauncher/.MainActivity','com.android.tv.settings/.system.FallbackHome')
            package_states=$states
        }
        journal=[ordered]@{
            original_home='com.google.android.tvlauncher/.MainActivity'
            selected_home=if($CustomHome){'com.fader.freemyprojector/io.freemytv.HomeActivity'}else{'com.google.android.tvlauncher/.MainActivity'}
            package_changes=@($journalChanges)
        }
    }
    $dest=Join-Path $temp ($Scenario+'.json')
    $mock | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $dest -Encoding UTF8
    return $dest
}
function Test-Success([string]$Label,[string]$MockPath,[int]$ExpectedSteps,[int]$FaultStep) {
    $result=(& $script:sim -BaselineDirectory $script:baselineFolder -ScenarioPath $MockPath -FailAtStep $FaultStep) | ConvertFrom-Json
    $expectedStatus=if($FaultStep -gt 0){'mock-failure-injected'}else{'mock-restored'}
    Assert ($result.status -eq $expectedStatus) "$Label: wrong status"
    Assert (@($result.planned_actions).Count -eq $ExpectedSteps) "$Label: incorrect count of expected actions"
    Assert ($result.device_writes -eq 0 -and $result.physical_device_access -eq 'none') "$Label: must remain offline"
    Assert ($result.home_switch_blocked -eq $true -and $result.mode -eq 'OFFLINE_MOCK_ONLY') "$Label: guard unavailable"
    Assert ($result.mock_verification_passed -eq ($FaultStep -eq 0)) "$Label: verification fail/pass mismatch"
    Write-Host "PASS: $Label"
    return $result
}
function Test-Refusal([string]$Label,[string]$MockPath,[string]$BaselineFolder) {
    $err=''
    try { & $script:sim -BaselineDirectory $BaselineFolder -ScenarioPath $MockPath | Out-Null }
    catch { $err=$_.Exception.Message }
    Assert ($err -match '^P-04D OFFLINE simulation REFUSED:') "$Label: refused incorrectly: $err"
    Write-Host "PASS (fail closed): $Label"
}
try {
    $env:FMP_MOCK_CASE='connected'
    $env:FMP_MOCK_LOG=Join-Path $temp 'setup-mock-adb.calls.txt'
    $saved=(& $save -AdbPath $fake -OutputDirectory $temp) | ConvertFrom-Json
    Assert ($saved.status -eq 'saved') 'Fake baseline creation failed'
    $script:baselineFolder=Join-Path $temp $saved.record_name
    $baseFile=Join-Path $script:baselineFolder 'baseline.private.json'
    $script:base=Get-Content -LiteralPath $baseFile -Raw | ConvertFrom-Json
    $baselineHash=(Get-FileHash -LiteralPath $baseFile -Algorithm SHA256).Hash

    # No existing journalled changes => an idempotent no-op.
    $noop=Build-Mock 'noop'
    $same=Test-Success 'idempotent baseline = zero steps' $noop 0 0
    Assert ($same.final_mock_home -eq 'com.google.android.tvlauncher/.MainActivity') 'Wrong stock HOME'
    $scenario=Build-Mock 'custom-home-plus-state' -CustomHome -ChangedPackage
    $restored=Test-Success 'mock revert HOME and only journalled disabled-state' $scenario 2 0
    Assert ($restored.planned_actions[0].kind -eq 'restore-home') 'HOME should be first'
    Assert ($restored.planned_actions[1].kind -eq 'restore-package-state') 'Journal should drive package recovery'
    Assert ($restored.planned_actions[1].target -eq 'disabled') 'Originally disabled package must stay disabled'
    Assert ($restored.planned_actions[1].package -eq 'com.example.otherapp') 'Unexpected package modified'
    Assert ($restored.final_mock_home -eq 'com.google.android.tvlauncher/.MainActivity') 'Stock HOME not restored in mock'
    [void](Test-Success 'fault injection before HOME restoration' $scenario 2 1)
    [void](Test-Success 'fault injection before package restoration' $scenario 2 2)
    $noState=Build-Mock 'home-only' -CustomHome
    [void](Test-Success 'mock restore HOME without package operations' $noState 1 0)
    $stateOnly=Build-Mock 'state-only' -ChangedPackage
    [void](Test-Success 'mock restore package state without HOME change' $stateOnly 1 0)

    Test-Refusal 'unlogged state drift' (Build-Mock 'unexpected-change' -UnexpectedChange) $script:baselineFolder
    Test-Refusal 'wrong firmware' (Build-Mock 'wrong-firmware' -BadFirmware) $script:baselineFolder
    Test-Refusal 'fallback HOME' (Build-Mock 'fallback-home' -BadFallback) $script:baselineFolder
    Test-Refusal 'protected OEM disabled' (Build-Mock 'oem-disabled' -DisabledOem) $script:baselineFolder
    Test-Refusal 'baseline package vanished' (Build-Mock 'package-missing' -MissingPackage) $script:baselineFolder
    Test-Refusal 'protected package in journal' (Build-Mock 'oem-in-journal' -UnknownJournal) $script:baselineFolder

    $tampered=Join-Path $temp 'tampered-baseline'
    [void](New-Item -ItemType Directory -Path $tampered)
    Copy-Item -LiteralPath $baseFile -Destination (Join-Path $tampered 'baseline.private.json')
    Copy-Item -LiteralPath (Join-Path $script:baselineFolder 'SHA256SUMS.txt') -Destination (Join-Path $tampered 'SHA256SUMS.txt')
    Add-Content -LiteralPath (Join-Path $tampered 'baseline.private.json') -Value ' '
    Test-Refusal 'tampered baseline' $noop $tampered
    Assert ((Get-FileHash -LiteralPath $baseFile -Algorithm SHA256).Hash -eq $baselineHash) 'Original baseline damaged'
    Assert (@(Get-Content -LiteralPath $env:FMP_MOCK_LOG).Count -gt 0) 'Fixture never used'
    # The simulator itself must have no ADB invocation path.
    $source=Get-Content -LiteralPath $sim -Raw
    foreach($pattern in @('(?im)^\s*(?:&\s*)?adb(?:\.exe)?\s+','(?i)Start-Process','(?i)Invoke-Expression','(?i)pm\s+disable','(?i)set-home-activity')) {
        Assert ($source -notmatch $pattern) "Forbidden execution-like content in simulator: $pattern"
    }
    Write-Host 'All offline P-04D rollback simulation tests passed. No projector was touched.'
} finally {
    Remove-Item Env:FMP_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item Env:FMP_MOCK_LOG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
