param(
    [Parameter(Mandatory = $true)][string]$PreviousApk,
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    [string]$BuildToolsPath
)
$ErrorActionPreference = 'Stop'
$previous = (Resolve-Path -LiteralPath $PreviousApk).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    & flutter build apk "--$Mode" --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    $candidate = Join-Path $repoRoot "build/app/outputs/flutter-apk/app-$Mode.apk"
    & (Join-Path $PSScriptRoot 'Test-ApkUpgrade.ps1') -PreviousApk $previous -CandidateApk $candidate -BuildToolsPath $BuildToolsPath
    Write-Output 'Package identity/version/signature checks passed. Database and device upgrade checks are still required before distribution.'
} finally {
    Pop-Location
}
