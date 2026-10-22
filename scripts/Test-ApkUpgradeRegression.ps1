# Read-only integration checks against the archived, signed APKs. No phone needed.
param(
    [string]$PreviousApk,
    [string]$CandidateApk,
    [string]$BuildToolsPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $PreviousApk) { $PreviousApk = Join-Path $repoRoot 'releases/Arsivcim-v2.4.0.apk' }
if (-not $CandidateApk) { $CandidateApk = Join-Path $repoRoot 'releases/v2.5.2-debug/Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk' }
$gate = Join-Path $PSScriptRoot 'Test-ApkUpgrade.ps1'
$base = @{ PreviousApk=$PreviousApk; CandidateApk=$CandidateApk; BuildToolsPath=$BuildToolsPath }

function Invoke-Gate([hashtable]$Extra) {
    $arguments = $base.Clone()
    foreach ($key in $Extra.Keys) { $arguments[$key] = $Extra[$key] }
    $output = [System.Collections.Generic.List[string]]::new()
    $failure = $null
    try { & $gate @arguments | ForEach-Object { $output.Add([string]$_) } }
    catch { $failure = $_.Exception.Message }
    $report = if ($output.Count) { ($output -join "`n") | ConvertFrom-Json } else { $null }
    return [pscustomobject]@{ report=$report; failure=$failure }
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Regression failed: $Message" }
}

$baseline = Invoke-Gate @{}
Assert-True ($null -eq $baseline.failure -and $baseline.report.compatible) 'Fixture APKs must be a valid package upgrade with the same signer.'
Assert-True ($baseline.report.checkedScope -eq 'package-only' -and $null -eq $baseline.report.device) 'No device supplied must remain explicitly package-only.'
$minSdk = [int]$baseline.report.candidate.minSdk
$supportedAbi = @($baseline.report.candidate.nativeAbis)[0]
Assert-True ($minSdk -gt 1 -and [bool]$supportedAbi) 'Fixtures must contain a minimum API and native libraries.'

$valid = Invoke-Gate @{ DeviceSdk=$minSdk; DeviceAbis=@('unsupported-test-abi', $supportedAbi) }
Assert-True ($null -eq $valid.failure -and $valid.report.compatible) 'The minimum API and any matching device ABI must pass.'
Assert-True ($valid.report.checkedScope -eq 'package-and-device-platform') 'Device checks must be reported.'

$low = Invoke-Gate @{ DeviceSdk=($minSdk - 1); DeviceAbis=@($supportedAbi) }
Assert-True ($null -ne $low.failure -and -not $low.report.compatible -and $low.report.failures.Count -eq 1 -and $low.report.failures[0] -like 'Device API*below*') 'An old device must fail solely on minimum API.'

$wrongAbi = Invoke-Gate @{ DeviceSdk=$minSdk; DeviceAbis=@('unsupported-test-abi') }
Assert-True ($null -ne $wrongAbi.failure -and -not $wrongAbi.report.compatible -and $wrongAbi.report.failures.Count -eq 1 -and $wrongAbi.report.failures[0] -like 'No candidate native ABI*') 'An incompatible CPU must fail solely on ABI.'

foreach ($incomplete in @(@{DeviceSdk=$minSdk}, @{DeviceAbis=@($supportedAbi)}, @{DeviceSdk=0; DeviceAbis=@($supportedAbi)})) {
    $result = Invoke-Gate $incomplete
    Assert-True ($result.failure -like 'Device checks require both*' -and $null -eq $result.report) 'Incomplete or invalid platform information must not silently skip validation.'
}
$invalidAbi = Invoke-Gate @{ DeviceSdk=$minSdk; DeviceAbis=@('') }
Assert-True ($null -ne $invalidAbi.failure -and $null -eq $invalidAbi.report) 'Empty ABI must not silently pass.'

$sameVersion = Invoke-Gate @{ PreviousApk=$CandidateApk; DeviceSdk=$minSdk; DeviceAbis=@($supportedAbi) }
Assert-True ($null -ne $sameVersion.failure -and -not $sameVersion.report.compatible -and $sameVersion.report.failures.Count -eq 1 -and $sameVersion.report.failures[0] -like '*versionCode*') 'Device compatibility must not bypass the version upgrade check.'
Write-Output 'PASS: 9 APK upgrade regression scenarios (real APK metadata and verified signatures; no device changes).'
