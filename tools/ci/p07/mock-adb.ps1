#requires -Version 5.1
# Offline fake ADB. DO NOT use on real projector.
$key = $args -join ' '
$case = [string]$env:P07_MOCK_CASE
$packages = @(
 'com.google.android.tvlauncher','com.android.tv.settings',
 'com.fengmi.projector.imaging','com.fengmi.fmsettings','com.fengmi.platform',
 'com.formovie.fmutils','com.formovie.gsettings','com.formovie.launchboard',
 'com.droidlogic','com.droidlogic.tvinput','com.android.camera2',
 'com.example.one','com.example.two','com.example.three','com.example.four'
)
if ($key -eq 'devices') {
    'List of devices attached'
    'MOCK_DEVICE device'
    if ($case -eq 'multiple') { 'MOCK_SECOND device' }
    exit 0
}
if ($key -eq 'shell am get-current-user') {
    if ($case -eq 'other-user') { '10' } else { '0' }
    exit 0
}
if ($key -match '^shell getprop (.+)$') {
    switch ($Matches[1]) {
       'ro.product.model' { if ($case -eq 'other-model') { 'WrongModel' } else { 'MiProjM05' } }
       'ro.product.device' { 'eva' }
       'ro.build.version.release' { '9' }
       'ro.build.version.sdk' { '28' }
       'ro.build.display.id' { 'PQ3B.190705.003.4185' }
       default { exit 2 }
    }
    exit 0
}
if ($key -eq 'shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') {
    if ($case -eq 'changed-home') { 'com.android.tv.settings/.SettingsActivity' }
    else { 'com.google.android.tvlauncher/.MainActivity' }
    exit 0
}
if ($key -match '^shell pm list packages(?: (.*))?$') {
    $flags = if ($Matches.ContainsKey(1)) { [string]$Matches[1] } else { '' }
    if ($flags -eq '-d' -or $flags -eq '-d --user 0') { exit 0 }
    if ($flags -notin @('','-e','--user 0','-e --user 0')) { exit 2 }
    foreach ($p in $packages) {
        if ($case -eq 'missing-oem' -and $p -eq 'com.fengmi.platform') { continue }
        "package:$p"
    }
    exit 0
}
if ($key -eq 'shell cat /proc/meminfo') {
    if ($case -eq 'bad-meminfo') { 'MemTotal: abc kB'; 'MemAvailable: 7 kB' }
    else { 'MemTotal: 2048000 kB'; 'MemAvailable: 512000 kB' }
    exit 0
}
if ($key -eq 'shell dumpsys meminfo com.fader.freemyprojector') {
    ' TOTAL 1234 56 7'
    exit 0
}
exit 3
