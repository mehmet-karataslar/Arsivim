param(
    [Parameter(Mandatory = $true)][string]$PreviousApk,
    [Parameter(Mandatory = $true)][string]$CandidateApk,
    [string]$BuildToolsPath,
    [Nullable[int]]$DeviceSdk,
    [string[]]$DeviceAbis
)
$ErrorActionPreference = 'Stop'
$checkDevice = $PSBoundParameters.ContainsKey('DeviceSdk') -or $PSBoundParameters.ContainsKey('DeviceAbis')
if ($checkDevice) {
    if ($null -eq $DeviceSdk -or $DeviceSdk -lt 1 -or -not $DeviceAbis) {
        throw 'Device checks require both a positive DeviceSdk and a nonempty DeviceAbis list.'
    }
    $DeviceAbis = @($DeviceAbis | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    if (@($DeviceAbis | Where-Object { $_ -notmatch '^[A-Za-z0-9_-]+$' }).Count -gt 0) {
        throw 'DeviceAbis contains an empty or invalid ABI name.'
    }
}
if (-not $BuildToolsPath) {
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
    $BuildToolsPath = (Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1).FullName
}
$aapt = Join-Path $BuildToolsPath 'aapt.exe'
$signer = Join-Path $BuildToolsPath 'apksigner.bat'
function Read-ApkIdentity([string]$ApkPath) {
    $resolved = (Resolve-Path -LiteralPath $ApkPath).Path
    $badging = & $aapt dump badging $resolved
    if ($LASTEXITCODE -ne 0) { throw "APK metadata cannot be read: $resolved" }
    $packageLine = $badging | Where-Object { $_ -match '^package:' } | Select-Object -First 1
    if ($packageLine -notmatch "name='([^']+)' versionCode='(\d+)' versionName='([^']+)'") {
        throw "APK version metadata is missing: $resolved"
    }
    $package = $Matches[1]
    $code = [long]$Matches[2]
    $name = $Matches[3]
    $sdkLine = $badging | Where-Object { $_ -match '^sdkVersion:' } | Select-Object -First 1
    if ($sdkLine -notmatch "^sdkVersion:'(\d+)'$") { throw "Numeric minimum SDK metadata is missing: $resolved" }
    $minSdk = [int]$Matches[1]
    $nativeLine = $badging | Where-Object { $_ -match '^native-code:' } | Select-Object -First 1
    $abis = @()
    if ($nativeLine) {
        $abis = @([regex]::Matches($nativeLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        if ($abis.Count -eq 0) { throw "Native ABI metadata cannot be read: $resolved" }
    }
    $certs = & $signer verify --print-certs $resolved
    if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed: $resolved" }
    $digests = @($certs | ForEach-Object {
        if ($_ -match '^(?:Signer #\d+|V[0-9.]+ Signer):? certificate SHA-256 digest: ([a-fA-F0-9]+)$') { $Matches[1].ToLowerInvariant() }
    } | Sort-Object -Unique)
    if ($digests.Count -eq 0) { throw "No verified signing certificate: $resolved" }
    [pscustomobject]@{ path=$resolved; package=$package; versionCode=$code; versionName=$name; certificates=$digests; minSdk=$minSdk; nativeAbis=$abis }
}
$previous = Read-ApkIdentity $PreviousApk
$candidate = Read-ApkIdentity $CandidateApk
$failures = @()
if ($previous.package -cne $candidate.package) { $failures += 'Application ID differs; this would be a separate application.' }
if ($candidate.versionCode -le $previous.versionCode) { $failures += 'The update versionCode must be greater than the installed version.' }
if (($previous.certificates -join ',') -cne ($candidate.certificates -join ',')) {
    $failures += 'Signing certificate differs. Use the original key, including the original debug key. Do not uninstall the existing app.'
}
$device = $null
if ($checkDevice) {
    $device = [pscustomobject]@{ sdk=$DeviceSdk; abis=$DeviceAbis }
    if ($DeviceSdk -lt $candidate.minSdk) {
        $failures += "Device API $DeviceSdk is below the candidate minimum API $($candidate.minSdk)."
    }
    if ($candidate.nativeAbis.Count -gt 0 -and @($candidate.nativeAbis | Where-Object { $_ -cin $DeviceAbis }).Count -eq 0) {
        $failures += 'No candidate native ABI is supported by the device.'
    }
}
$scope = if ($checkDevice) { 'package-and-device-platform' } else { 'package-only' }
[pscustomobject]@{ previous=$previous; candidate=$candidate; device=$device; checkedScope=$scope; compatible=($failures.Count -eq 0); failures=$failures } | ConvertTo-Json -Depth 5
if ($failures.Count -gt 0) { throw 'APK update compatibility check failed. This candidate must not be installed as an update.' }
