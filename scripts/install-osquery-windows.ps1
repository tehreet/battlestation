# install-osquery-windows.ps1
# -----------------------------------------------------------------------------
# Install osquery on Windows. Idempotent: exits cleanly if already installed.
# Requires elevation (winget install for machine-wide MSI).
# Invoke from an elevated PowerShell, or via:
#   powershell.exe -ExecutionPolicy Bypass -File install-osquery-windows.ps1
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = [Security.Principal.WindowsPrincipal]::new($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OsqueryPath {
    $cmd = Get-Command osqueryi.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $defaultPath = 'C:\Program Files\osquery\osqueryi.exe'
    if (Test-Path $defaultPath) { return $defaultPath }
    return $null
}

# Short-circuit if already installed.
$existing = Get-OsqueryPath
if ($existing) {
    $ver = & $existing --version 2>&1
    Write-Host "osquery already installed at: $existing"
    Write-Host "version: $ver"
    exit 0
}

if (-not (Test-Elevated)) {
    Write-Error "winget install for osquery needs an elevated PowerShell. Re-run as Administrator."
    exit 1
}

# winget should be present on modern Win11; bail with a clear message if not.
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Error @"
winget not found. Install App Installer from the Microsoft Store, or download the
osquery MSI manually from https://osquery.io/downloads/ and install it.
"@
    exit 1
}

Write-Host "Installing osquery via winget..."
$wingetArgs = @(
    'install',
    '--id=osquery.osquery',
    '-e',
    '--accept-source-agreements',
    '--accept-package-agreements'
)
& winget @wingetArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "winget install failed (exit $LASTEXITCODE). Try the manual MSI from https://osquery.io/downloads/."
    exit $LASTEXITCODE
}

# Verify post-install. Path may not have refreshed in this session — check the default location.
$installed = Get-OsqueryPath
if (-not $installed) {
    Write-Error "Install reported success but osqueryi.exe not found. Check C:\Program Files\osquery\."
    exit 1
}

$ver = & $installed --version 2>&1
Write-Host "osquery installed: $installed"
Write-Host "version: $ver"
