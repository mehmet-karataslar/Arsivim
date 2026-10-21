$ErrorActionPreference = 'SilentlyContinue'

# Close the app cleanly first so Flutter can replace its Windows build files.
$runningApps = Get-Process -Name 'arsiv_uygulamasi'
foreach ($app in $runningApps) {
    if ($app.MainWindowHandle -ne 0) {
        [void]$app.CloseMainWindow()
    }
}

if ($runningApps) {
    $runningApps | Wait-Process -Timeout 5
    Get-Process -Name 'arsiv_uygulamasi' | Stop-Process -Force
}

exit 0
