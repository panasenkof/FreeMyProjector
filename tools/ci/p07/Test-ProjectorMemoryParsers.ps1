#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../ProjectorMemoryParsers.ps1')
function Expect-Failure([string]$Name,[scriptblock]$Body) {
    try { & $Body | Out-Null } catch { return }
    throw "Unexpected parser success: $Name"
}
function Assert-Same($Actual,$Expected,[string]$Name) {
    if ($Actual -ne $Expected) { throw "Unexpected $Name" }
}
$valid = ConvertFrom-ProjectorMeminfo "MemTotal: 2048000 kB`nMemFree: 10 kB`nMemAvailable: 512000 kB"
Assert-Same $valid.MemTotal 2048000 'total'
Assert-Same $valid.MemAvailable 512000 'available'
Expect-Failure 'missing available' { ConvertFrom-ProjectorMeminfo 'MemTotal: 2048000 kB' }
Expect-Failure 'duplicate' { ConvertFrom-ProjectorMeminfo "MemTotal: 2048000 kB`nMemTotal: 123 kB`nMemAvailable: 1 kB" }
Expect-Failure 'malformed' { ConvertFrom-ProjectorMeminfo "MemTotal: xxx kB`nMemAvailable: 1 kB" }
Expect-Failure 'available exceeds total' { ConvertFrom-ProjectorMeminfo "MemTotal: 10 kB`nMemAvailable: 20 kB" }
Expect-Failure 'overflow' { ConvertFrom-ProjectorMeminfo "MemTotal: 9999999999999999999999999 kB`nMemAvailable: 1 kB" }
Expect-Failure 'zero total' { ConvertFrom-ProjectorMeminfo "MemTotal: 0 kB`nMemAvailable: 0 kB" }
Assert-Same (ConvertFrom-ProjectorPss " TOTAL 1234 567 89") 1234 'pss'
if ($null -ne (ConvertFrom-ProjectorPss 'Process not found')) { throw 'Unexpected absent PSS' }
if ($null -ne (ConvertFrom-ProjectorPss " TOTAL 123 45 6`n TOTAL 456 7 8")) { throw 'Ambiguous PSS was accepted' }
if ($null -ne (ConvertFrom-ProjectorPss ' TOTAL 9999999999999999999999999 1 1')) { throw 'Overflow PSS was accepted' }
Write-Output 'P-07 isolated parser cases: PASS'
