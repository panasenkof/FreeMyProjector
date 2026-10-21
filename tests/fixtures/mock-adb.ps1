# Fake ADB command for P-01 unit tests. Never connects to any real hardware.
$ErrorActionPreference = 'Stop'
$argv = @($args)
$line = $argv -join ' '
if ($env:MOCK_ADB_LOG) { Add-Content -LiteralPath $env:MOCK_ADB_LOG -Value $line }
$scenario = $env:MOCK_ADB_SCENARIO
if ($argv.Count -lt 1) { return }

if ($argv[0] -eq 'devices') {
    switch ($scenario) {
        'unauthorized' { "List of devices attached"; "unit-test-unique-serial-abcdef12345 unauthorized"; return }
        'offline' { "List of devices attached"; "unit-test-unique-serial-abcdef12345 offline"; return }
        'none' { "List of devices attached"; return }
        'multiple' {
            "List of devices attached"
            "unit-test-unique-serial-abcdef12345 device"
            "another-private-serial-9876 device"
            return
        }
        'adb-error' { throw 'Connection failed: unit-test-unique-serial-abcdef12345' }
        default { "List of devices attached"; "unit-test-unique-serial-abcdef12345 device"; return }
    }
}

if ($argv.Count -ge 3 -and $argv[0] -eq 'shell' -and $argv[1] -eq 'getprop') {
    $props = @{
        'ro.product.model' = 'Mi Smart Compact Projector'
        'ro.product.device' = 'mantis'
        'ro.build.version.release' = '9'
        'ro.build.version.sdk' = '28'
        'ro.build.display.id' = 'PQ3A.190801.002'
    }
    $key = $argv[2]
    if ($scenario -eq 'missing-fields' -and $key -eq 'ro.product.device') { return }
    if ($scenario -eq 'sensitive-values' -and $key -eq 'ro.build.display.id') {
        'private-user@192.168.1.23'; return
    }
    if ($props.ContainsKey($key)) { $props[$key]; return }
    throw 'Unexpected property'
}
if ($line -like 'shell cmd package resolve-activity*') {
    if ($scenario -eq 'missing-fields') { 'Unsupported firmware command'; return }
    'com.google.android.tvlauncher/.MainActivity'
    return
}
throw 'Unexpected ADB arguments'
