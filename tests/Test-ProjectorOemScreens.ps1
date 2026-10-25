#requires -Version 5.1
# P-04A static safety check: factory links are preflight-only, never launched.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$path=Join-Path $root 'app/src/io/freemytv/ProjectorFactoryScreens.java'
$src=Get-Content -LiteralPath $path -Raw
function Assert([bool]$Ok,[string]$Why) { if(-not $Ok){throw "P-04A FAILED: $Why"} }
Assert ($src -match 'Build.VERSION.SDK_INT == 28') 'firmware SDK 28 gate missing'
Assert ($src -match '"MiProjM05".equals\(Build.MODEL\)') 'model gate missing'
Assert ($src -match '"eva".equals\(Build.DEVICE\)') 'device gate missing'
Assert ($src -match '"PQ3B.190705.003.4185".equals\(Build.DISPLAY\)') 'exact build gate missing'
Assert ($src -match 'PackageManager\.getActivityInfo|pm\.getActivityInfo') 'alias metadata check absent'
Assert ($src -match '!info.exported') 'exported guard missing'
Assert ($src -match 'info.permission != null') 'permission denial absent'
Assert ($src -match 'TARGET.equals\(info.targetActivity\)') 'alias target guard missing'
Assert ($src -match 'START_FOCUS' -and $src -match 'START_KEYSTONE') 'focus/keystone intents absent'
Assert ($src -notmatch 'START_AUTO_KEYSTONE|AutoKeystone|GuideActivity') 'automated calibration must not be available'
Assert ($src -notmatch '(?m)^\s*(?:\w+\.)?startActivity\s*\(') 'activity launch forbidden'
Assert ($src -notmatch 'getSystemService|Runtime\.getRuntime|ProcessBuilder|settings put|set-home-activity|pm disable') 'system mutation forbidden'
Assert ($src -match 'case FOCUS:' -and $src -match 'case KEYSTONE:') 'supported aliases must be explicit'
Write-Host 'PASS: P-04A factory screen preflight is passive and locked to audited MiProjM05/.4185'
