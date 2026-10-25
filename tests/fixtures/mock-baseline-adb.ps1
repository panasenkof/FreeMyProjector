#requires -Version 5.1
# Offline P-04B ADB fake; NEVER invokes real hardware.
$ErrorActionPreference = 'Stop'
$argv = @($args)
$cmd = $argv -join ' '
if ($env:FMP_MOCK_LOG) { Add-Content -LiteralPath $env:FMP_MOCK_LOG -Value $cmd }
$case = $env:FMP_MOCK_CASE

if ($cmd -eq 'devices') {
    'List of devices attached'
    if ($case -eq 'unauthorized') { 'private-serial-123 unauthorized'; return }
    if ($case -eq 'multiple') { 'private-serial-123 device'; 'private-serial-456 device'; return }
    'private-serial-123 device'
    return
}
$props = @{
    'ro.product.model'='MiProjM05'
    'ro.product.device'='eva'
    'ro.build.version.release'='9'
    'ro.build.version.sdk'='28'
    'ro.build.display.id'='PQ3B.190705.003.4185'
}
if ($cmd -match '^shell getprop (\S+)$') {
    $key = $Matches[1]
    if (-not $props.ContainsKey($key)) { throw 'Unexpected property' }
    if ($case -eq 'wrong-firmware' -and $key -eq 'ro.build.display.id') { 'PQ3B.190705.003.2102'; return }
    $props[$key]
    return
}
if ($cmd -eq 'shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') {
    if ($case -eq 'wrong-home') { 'android'; return }
    'com.google.android.tvlauncher/.MainActivity'
    return
}
if ($cmd -eq 'shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME') {
    if ($case -eq 'missing-claimant') { 'com.android.tv.settings/.system.FallbackHome'; return }
    if ($case -eq 'query-error') { throw 'private-serial-123 query error' }
    'com.google.android.tvlauncher/.MainActivity'
    'com.android.tv.settings/.system.FallbackHome'
    return
}
$all = @(
'android','com.google.android.tvlauncher','com.android.tv.settings',
'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
'com.droidlogic','com.droidlogic.tvinput','com.android.camera2',
'com.fengmi.autofocustest','com.droidlogic.overlay',
'com.google.android.gms','com.google.android.gsf','com.android.systemui',
'com.android.vending','com.google.android.katniss','com.example.otherapp'
)
$off = @('com.example.otherapp')
if ($case -eq 'zero-disabled') { $off = @() }
if ($case -eq 'protected-disabled') { $off = @('com.fengmi.projector.imaging') }
if ($cmd -eq 'shell pm list packages') {
    $all | ForEach-Object { "package:$_" }
    return
}
if ($cmd -eq 'shell pm list packages -d') {
    $off | ForEach-Object { "package:$_" }
    return
}
if ($cmd -eq 'shell pm list packages -e') {
    $all | Where-Object { $_ -notin $off } | ForEach-Object { "package:$_" }
    if ($case -eq 'inconsistent') { "package:$($off[0])" }
    if ($case -eq 'malformed') { 'package:private-serial-123@192.168.1.25' }
    return
}
throw 'Unexpected ADB arguments'
