param(
    [Parameter(Mandatory = $true)][string]$CandidateApk,
    [string]$BuildToolsPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$identity = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'android/release-identity.json') | ConvertFrom-Json
$versionLine = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:' }
if ($versionLine -notmatch '^version:\s*([^+\s]+)\+(\d+)\s*$') { throw 'Expected versionName+versionCode in pubspec.yaml.' }
$expectedName = $Matches[1]
$expectedCode = [long]$Matches[2]
if (-not $BuildToolsPath) {
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
    $BuildToolsPath = (Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1).FullName
}
$resolved = (Resolve-Path -LiteralPath $CandidateApk).Path
$badging = & (Join-Path $BuildToolsPath 'aapt.exe') dump badging $resolved
if ($LASTEXITCODE -ne 0) { throw 'APK metadata could not be read.' }
$packageLine = $badging | Where-Object { $_ -match '^package:' } | Select-Object -First 1
if ($packageLine -notmatch "name='([^']+)' versionCode='(\d+)' versionName='([^']+)'") { throw 'APK identity is missing.' }
$packageName = $Matches[1]
$versionCode = [long]$Matches[2]
$versionName = $Matches[3]
$certs = & (Join-Path $BuildToolsPath 'apksigner.bat') verify --print-certs $resolved
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$digests = @($certs | ForEach-Object {
    if ($_ -match '^(?:Signer #\d+|V[0-9.]+ Signer):? certificate SHA-256 digest: ([a-fA-F0-9]+)$') { $Matches[1].ToLowerInvariant() }
} | Sort-Object -Unique)
$failures = @()
if ($packageName -cne $identity.applicationId) { $failures += 'Wrong application ID for the new installation.' }
if ($versionName -cne $expectedName -or $versionCode -ne $expectedCode) { $failures += 'APK version differs from pubspec.yaml.' }
if ($digests.Count -ne 1 -or $digests[0] -cne $identity.certificateSha256) { $failures += 'Signing key differs from the persistent release identity.' }
if (@($badging | Where-Object { $_ -match '^application-debuggable' }).Count -gt 0) { $failures += 'A release APK must not be debuggable.' }
[pscustomobject]@{
    path=$resolved; applicationId=$packageName; versionName=$versionName; versionCode=$versionCode
    certificateSha256=$digests; verified=($failures.Count -eq 0); failures=$failures
} | ConvertTo-Json -Depth 4
if ($failures.Count) { throw 'Android release verification failed.' }
