param(
    [string]$Serial,
    [string]$AdbPath,
    [string]$CandidateApk
)
$ErrorActionPreference = 'Stop'
if (-not $AdbPath) {
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
    $AdbPath = Join-Path $sdkRoot 'platform-tools/adb.exe'
}
$devices = & $AdbPath devices
if ($LASTEXITCODE -ne 0) { throw 'ADB devices could not be read.' }
$ready = @($devices | ForEach-Object { if ($_ -match '^(\S+)\s+device$') { $Matches[1] } })
if (-not $Serial) {
    if ($ready.Count -ne 1) { throw 'Connect and authorize exactly one Android device, or specify -Serial.' }
    $Serial = $ready[0]
}
if ($Serial -notin $ready) { throw 'The selected Android device is not connected and authorized.' }
$paths = & $AdbPath -s $Serial shell pm path com.example.arsiv_uygulamasi
if ($LASTEXITCODE -ne 0) { throw 'Installed package could not be inspected.' }
$base = @($paths | Where-Object { $_ -match '^package:.*base\.apk\s*$' })
if ($base.Count -ne 1) { throw 'Exactly one installed Arsivim base APK was expected. No changes were made.' }
$remote = ($base[0] -replace '^package:', '').Trim()
$repoRoot = Split-Path -Parent $PSScriptRoot
$output = Join-Path $repoRoot ('artifacts/upgrade-audit/device-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$installedApk = Join-Path $output 'installed-base.apk'
& $AdbPath -s $Serial pull $remote $installedApk
if ($LASTEXITCODE -ne 0) { throw 'Installed APK could not be copied for inspection.' }
$deviceSdk = (& $AdbPath -s $Serial shell getprop ro.build.version.sdk).Trim()
Write-Output "Installed APK copied for inspection: $installedApk (Android API $deviceSdk)"
Write-Output 'The phone application and its data were not changed. This file contains application code, not an archive backup.'
if ($CandidateApk) {
    & (Join-Path $PSScriptRoot 'Test-ApkUpgrade.ps1') -PreviousApk $installedApk -CandidateApk $CandidateApk
}
