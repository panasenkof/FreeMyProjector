#requires -Version 5.1
<#
.SYNOPSIS
  Test simulated Android 9 HOME rollback on THIS PC using the owner's verified P-04B snapshot.
.DESCRIPTION
  OFFLINE ONLY. Creates temporary fictional scenarios in the parent project workspace,
  runs the offline simulator, removes temporary files, and prints redacted results.
  NO adb, NO projector connection, NO changes to saved snapshot or Android.
.EXAMPLE
  .\tools\Test-ProjectorRollbackLocally.ps1 -SnapshotDirectory 'D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d'
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SnapshotDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Stop-Test([string]$Why) { throw "P-04D LOCAL TEST STOPPED: $Why. No device commands executed." }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$workspace = Split-Path -Parent $repo
$checker = Join-Path $PSScriptRoot 'Compare-ProjectorBaseline.ps1'
$simulator = Join-Path $PSScriptRoot 'Invoke-ProjectorRollbackSimulation.ps1'
if (-not (Test-Path -LiteralPath $checker -PathType Leaf) -or
    -not (Test-Path -LiteralPath $simulator -PathType Leaf)) { Stop-Test 'Required offline tools missing' }

# Verify original bytes before reading snapshot fields or preparing any scenario.
$integrity = (& $checker -SnapshotDirectory $SnapshotDirectory -VerifyOnly) | ConvertFrom-Json
if ($integrity.status -cne 'verified' -or $integrity.sha256 -cne 'match' -or
    $integrity.device_access -cne 'none' -or [int]$integrity.device_writes -ne 0) {
    Stop-Test 'Saved snapshot integrity verification failed'
}
$baselineFile = Join-Path $SnapshotDirectory 'baseline.private.json'
try { $baseline = Get-Content -LiteralPath $baselineFile -Raw | ConvertFrom-Json }
catch { Stop-Test 'Verified snapshot JSON could not be read' }
$hashBefore = (Get-FileHash -LiteralPath $baselineFile -Algorithm SHA256).Hash

$factoryHome = 'com.google.android.tvlauncher/.MainActivity'
$fictionalHome = 'com.fader.freemyprojector/io.freemytv.HomeActivity'
$mockDir = Join-Path $workspace ('fmp-p04d-local-mock-'+[guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $mockDir) { Stop-Test 'Temporary mock path already exists' }

function New-Scenario {
    param([string]$Name,[bool]$SwitchHome,[string]$FlipPackage)
    $localStates = [ordered]@{}
    foreach ($p in @($baseline.package_states.PSObject.Properties)) {
        $localStates[$p.Name] = [string]$p.Value
    }
    if ($SwitchHome) { $localStates['com.fader.freemyprojector'] = 'enabled' }
    $journalChanges = @()
    if ($FlipPackage -ne '') {
        if (-not $localStates.Contains($FlipPackage)) { Stop-Test 'Mock package not present in saved baseline' }
        $before = [string]$localStates[$FlipPackage]
        $after = if ($before -eq 'enabled') { 'disabled' } else { 'enabled' }
        $localStates[$FlipPackage] = $after
        $journalChanges = @([ordered]@{ package=$FlipPackage; before=$before; after=$after })
    }
    $currentHome = if ($SwitchHome) { $fictionalHome } else { $factoryHome }
    $mock = [ordered]@{
        schema_version=1
        kind='OFFLINE_MOCK_ONLY'
        mock_device=[ordered]@{
            firmware=[ordered]@{
                model=$baseline.firmware.model
                device=$baseline.firmware.device
                android=[string]$baseline.firmware.android
                sdk=[int]$baseline.firmware.sdk
                build=$baseline.firmware.build
            }
            home=$currentHome
            home_claimants=@($factoryHome,$fictionalHome)
            package_states=$localStates
        }
        journal=[ordered]@{
            original_home=$factoryHome
            selected_home=$currentHome
            package_changes=@($journalChanges)
        }
    }
    $path = Join-Path $mockDir ($Name+'.json')
    $json = ConvertTo-Json -InputObject $mock -Depth 12
    [IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))
    return $path
}
function Assert-Sim {
    param([string]$TestName,[string]$ScenarioPath,[int]$ExpectedActions,[int]$FailStep,[string]$ExpectedStatus)
    $result = (& $simulator -BaselineDirectory $SnapshotDirectory -ScenarioPath $ScenarioPath -FailAtStep $FailStep) | ConvertFrom-Json
    if ($result.status -cne $ExpectedStatus -or
        @($result.planned_actions).Count -ne $ExpectedActions -or
        $result.physical_device_access -cne 'none' -or
        [int]$result.device_writes -ne 0 -or
        $result.home_switch_blocked -ne $true) {
        Stop-Test "Offline scenario failed expected safety constraints: $TestName"
    }
    if ($FailStep -eq 0 -and ($result.mock_verification_passed -ne $true -or
        $result.final_mock_home -cne $factoryHome)) {
        Stop-Test "Mock restoration did not match original state: $TestName"
    }
    if ($FailStep -gt 0 -and $result.mock_verification_passed -ne $false) {
        Stop-Test "Injected error was not detected: $TestName"
    }
    return [pscustomobject]@{
        test=$TestName
        status=$result.status
        planned_actions=$ExpectedActions
        simulated_steps_completed=[int]$result.mock_actions_completed
        verified=[bool]$result.mock_verification_passed
    }
}

$results = @()
try {
    [void](New-Item -ItemType Directory -Path $mockDir -ErrorAction Stop)
    $initialScenario = New-Scenario -Name 'untouched' -SwitchHome $false -FlipPackage ''
    $results += Assert-Sim 'already-original' $initialScenario 0 0 'mock-restored'

    $otherHomeScenario = New-Scenario -Name 'fictional-home-selected' -SwitchHome $true -FlipPackage ''
    $results += Assert-Sim 'restore-original-home' $otherHomeScenario 1 0 'mock-restored'
    $results += Assert-Sim 'failure-before-home-restore' $otherHomeScenario 1 1 'mock-failure-injected'

    # Optional package-state test is purely fictional; never changes any real package.
    # Use only known non-OEM candidates from the saved inventory.
    $candidate = ''
    foreach ($name in @(
        'com.google.android.tvrecommendations',
        'com.google.android.leanbacklauncher.recommendations',
        'com.google.android.youtube.tv',
        'com.netflix.ninja',
        'com.example.otherapp'
    )) {
        if (@($baseline.package_states.PSObject.Properties | Where-Object { $_.Name -ceq $name }).Count -eq 1) {
            $candidate = $name
            break
        }
    }
    $packageCase = 'skipped-no-approved-mock-package'
    if ($candidate -ne '') {
        $withPackage = New-Scenario -Name 'fictional-home-and-package' -SwitchHome $true -FlipPackage $candidate
        $results += Assert-Sim 'restore-home-and-package-state' $withPackage 2 0 'mock-restored'
        $results += Assert-Sim 'failure-before-package-restore' $withPackage 2 2 'mock-failure-injected'
        $packageCase = 'executed-offline-only'
    }
    $hashAfter = (Get-FileHash -LiteralPath $baselineFile -Algorithm SHA256).Hash
    if ($hashAfter -cne $hashBefore) { Stop-Test 'Original snapshot changed unexpectedly' }
    [pscustomobject]@{
        status='passed'
        mode='OFFLINE_MOCK_ONLY'
        source_baseline='verified'
        original_snapshot_unchanged=$true
        cases=@($results)
        package_state_mock=$packageCase
        device_access='none'
        device_writes=0
        home_switch_blocked=$true
        note='Simulated rollback on this PC only. No real projector rollback or firmware recovery was tested.'
    } | ConvertTo-Json -Depth 8
}
finally {
    if (Test-Path -LiteralPath $mockDir) {
        Remove-Item -LiteralPath $mockDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
