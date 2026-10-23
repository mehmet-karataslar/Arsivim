param([string]$InstallerPath = 'artifacts/distributions/v2.6.3/Arsivim-v2.6.3-windows-x64-setup.exe')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $repoRoot ('artifacts/installer-tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$testExe = Join-Path $testRoot 'InstallerTests.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe /platform:x64 "/out:$testExe" `
    /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll `
    (Join-Path $repoRoot 'windows/installer/InstallerCore.cs') (Join-Path $repoRoot 'windows/installer/InstallerTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'Installer tests did not compile.' }
& $testExe (Resolve-Path -LiteralPath $InstallerPath).Path $testRoot
if ($LASTEXITCODE -ne 0) { throw 'Installer regression tests failed.' }
