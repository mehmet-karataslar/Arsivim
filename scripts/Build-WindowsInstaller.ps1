param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$versionLine = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') |
    Where-Object { $_ -match '^version:' }
if ($versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'Expected a stable versionName+versionCode in pubspec.yaml.'
}
$appVersion = $Matches[1]
$buildNumber = $Matches[2]
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework C# compiler is required.' }
Push-Location $repoRoot
try {
    if (-not $SkipBuild) {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    }
    $bundle = Join-Path $repoRoot 'build/windows/x64/runner/Release'
    $exe = Get-Item -LiteralPath (Join-Path $bundle 'arsiv_uygulamasi.exe')
    $builtVersion = $exe.VersionInfo.ProductVersion
    if ($builtVersion -ne "$appVersion+$buildNumber") {
        throw "Bundle version mismatch: $builtVersion, expected $appVersion+$buildNumber."
    }
    foreach ($required in @('flutter_windows.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets')) {
        if (-not (Test-Path -LiteralPath (Join-Path $bundle $required))) {
            throw "Incomplete Windows bundle: $required is missing."
        }
    }
    # Flutter desktop requires the Visual C++ runtime on clean machines.
    # Bundle the app-local redistributable DLLs from the installed VS toolchain.
    $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
    $vsPath = & $vswhere -latest -products '*' -property installationPath
    if (-not $vsPath) { throw 'Visual Studio C++ redistributable directory not found.' }
    $crt = Get-ChildItem -LiteralPath (Join-Path $vsPath 'VC/Redist/MSVC') -Directory |
        Where-Object { $_.Name -match '^\d+\.' } |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $crt) { throw 'Visual C++ x64 runtime DLLs not found.' }
    Get-ChildItem -LiteralPath $crt.FullName -Filter '*.dll' |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $bundle -Force }
    # Resolve the locked package, not an arbitrary DLL from the developer PATH.
    $configPath = Join-Path $repoRoot '.dart_tool/package_config.json'
    $packages = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).packages
    $sqlitePackage = $packages | Where-Object { $_.name -eq 'sqflite_common_ffi' }
    $configUri = [Uri]::new($configPath)
    $sqliteRoot = [Uri]::new($configUri, $sqlitePackage.rootUri).LocalPath
    Copy-Item -LiteralPath (Join-Path $sqliteRoot 'lib/src/windows/sqlite3.dll') -Destination $bundle -Force
    $output = Join-Path $repoRoot "artifacts/distributions/v$appVersion"
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $installer = Join-Path $output "Arsivim-v$appVersion-windows-x64-setup.exe"
    $work = Join-Path $repoRoot 'build/windows-installer'
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $payload = Join-Path $work 'payload.zip'
    Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $payload -Force
    $digestFile = Join-Path $work 'payload.sha256'
    [IO.File]::WriteAllText($digestFile, (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash)
    $metadata = Join-Path $work 'Version.cs'
    $attributes = @"
using System.Reflection;
[assembly: AssemblyTitle("Arsivim Setup")]
[assembly: AssemblyProduct("Arsivim")]
[assembly: AssemblyVersion("$appVersion.0")]
[assembly: AssemblyFileVersion("$appVersion.$buildNumber")]
"@
    [IO.File]::WriteAllText($metadata, $attributes)
    & $compiler /nologo /target:winexe /platform:x64 /optimize+ "/out:$installer" `
        /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
        /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll `
        /reference:Microsoft.CSharp.dll `
        "/win32icon:$(Join-Path $repoRoot 'windows/runner/resources/app_icon.ico')" `
        "/resource:$payload,payload.zip" "/resource:$digestFile,payload.sha256" `
        $metadata (Join-Path $repoRoot 'windows/installer/InstallerCore.cs') (Join-Path $repoRoot 'windows/installer/Program.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer compilation failed.' }
    Get-FileHash -LiteralPath $installer -Algorithm SHA256
    Write-Output "Installer ready: $installer"
} finally {
    Pop-Location
}
