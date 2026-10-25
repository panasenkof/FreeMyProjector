#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$mock = Join-Path $PSScriptRoot 'mock-adb.ps1'
$probe = Join-Path $root 'tools/Measure-ProjectorMemoryReadOnly.ps1'
$temp = Join-Path $env:TEMP ('p07-mock-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
try {
    $names = @(
      'com.google.android.tvlauncher','com.android.tv.settings',
      'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
      'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
      'com.droidlogic','com.droidlogic.tvinput','com.android.camera2',
      'com.example.one','com.example.two','com.example.three','com.example.four'
    )
    $states = [ordered]@{}
    foreach ($name in $names) { $states[$name] = 'enabled' }
    $snapshot = [ordered]@{
      schema_version = 1
      status = 'read-only-baseline'
      firmware = [ordered]@{
        model='MiProjM05'; device='eva'; android='9'; sdk=28
        build='PQ3B.190705.003.4185'
      }
      home = [ordered]@{ resolved='com.google.android.tvlauncher/.MainActivity' }
      package_states = $states
    }
    $path = Join-Path $temp 'baseline.private.json'
    [IO.File]::WriteAllText($path,(ConvertTo-Json -InputObject $snapshot -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $temp 'SHA256SUMS.txt'),
        ($hash + '  baseline.private.json' + [Environment]::NewLine),
        (New-Object System.Text.UTF8Encoding($false)))

    $env:P07_MOCK_CASE = ''
    $result = (& $probe -SnapshotDirectory $temp -AdbPath $mock -Phase stock-before) | ConvertFrom-Json
    if ($result.status -cne 'read-only-sample' -or $result.mem_total_kib -ne 2048000 -or
        $result.mem_available_kib -ne 512000 -or $result.device_writes -ne 0 -or
        $result.stock_home_unchanged -ne $true) { throw 'Positive mock case failed' }

    $result2 = (& $probe -SnapshotDirectory $temp -AdbPath $mock -Phase preview-settings) | ConvertFrom-Json
    if ($result2.app_pss_kib -ne 1234) { throw 'Mock PSS parse failed' }

    foreach ($scenario in @('multiple','other-user','other-model','changed-home','missing-oem','bad-meminfo')) {
        $env:P07_MOCK_CASE = $scenario
        $failed = $false
        try { & $probe -SnapshotDirectory $temp -AdbPath $mock -Phase stock-before | Out-Null }
        catch { $failed = $true }
        if (-not $failed) { throw "Expected fail-closed error for $scenario" }
    }
    $env:P07_MOCK_CASE = ''
    Add-Content -LiteralPath $path -Value 'TAMPERED'
    $failed = $false
    try { & $probe -SnapshotDirectory $temp -AdbPath $mock | Out-Null }
    catch { $failed = $true }
    if (-not $failed) { throw 'Corrupted SHA256 snapshot passed' }
    Write-Output 'P-07 full offline fake-ADB scenarios: PASS'
} finally {
    Remove-Item Env:P07_MOCK_CASE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
