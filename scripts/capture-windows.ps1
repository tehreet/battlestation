# =============================================================================
# capture-windows.ps1 - Windows-side baseline capture.
#
# Runs every query in queries\windows\*.sql via osqueryi and collects
# supplementary data PowerShell can see that osquery can't (winget export,
# Windows capabilities, Defender status, GPU/display details, USB devices,
# power plan, boot config, etc.). Output lands in baselines\windows\<TS>\.
#
# Invoked from capture-all.sh via:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path> -Ts <ts>
#
# When the orchestrator passes -Ts, both Windows and WSL captures share a
# single timestamp. Standalone runs generate their own timestamp.
#
# Errors are recorded in _summary.md; the script continues on individual
# failures rather than aborting.
# =============================================================================

param([string]$Ts = "")

# Don't bail on individual failures - we want the rest of the capture.
$ErrorActionPreference = 'Continue'

if (-not $Ts -or $Ts -eq '') {
    $Ts = Get-Date -Format 'yyyy-MM-dd_HHmm'
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$OutDir    = Join-Path $RepoRoot "baselines\windows\$Ts"
$QueryDir  = Join-Path $RepoRoot 'queries\windows'
$Summary   = Join-Path $OutDir '_summary.md'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Errors = New-Object System.Collections.Generic.List[string]
function Note-Error {
    param([string]$Item, [string]$Reason)
    $Errors.Add("- ``$Item`` - $Reason")
}

# -----------------------------------------------------------------------------
# File-writing helpers - UTF-8 no BOM, LF line endings.
# -----------------------------------------------------------------------------
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-OutputFile {
    param([string]$Path, [string]$Content)
    if ($null -eq $Content) { $Content = '' }
    $normalized = $Content -replace "`r`n", "`n"
    if (-not $normalized.EndsWith("`n")) { $normalized = $normalized + "`n" }
    [System.IO.File]::WriteAllText($Path, $normalized, $Utf8NoBom)
}

# Always emit a JSON array, even for 0 or 1 row, so capture-all.sh's
# `jq -S '.'` post-process is uniform.
function Write-JsonArrayFile {
    param([string]$Path, $Items, [int]$Depth = 10)

    $arr = @()
    if ($null -ne $Items) {
        if ($Items -is [System.Collections.IEnumerable] -and -not ($Items -is [string])) {
            $arr = @($Items)
        } else {
            $arr = @($Items)
        }
    }

    if ($arr.Count -eq 0) {
        Write-OutputFile $Path "[]"
        return
    }

    # ConvertTo-Json unwraps single-element arrays; assemble manually to
    # guarantee array output.
    $parts = $arr | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth $Depth }
    Write-OutputFile $Path ("[`n" + ($parts -join ",`n") + "`n]")
}

# -----------------------------------------------------------------------------
# Locate osqueryi
# -----------------------------------------------------------------------------
$Osqueryi = (Get-Command osqueryi.exe -ErrorAction SilentlyContinue).Source
if (-not $Osqueryi) { $Osqueryi = 'C:\Program Files\osquery\osqueryi.exe' }
if (-not (Test-Path $Osqueryi)) {
    Write-Error "osqueryi.exe not found. Run scripts\install-osquery-windows.ps1 first."
    exit 1
}
$OsqueryVer = (& $Osqueryi --version 2>&1 | Out-String).Trim()

# -----------------------------------------------------------------------------
# osquery queries
# -----------------------------------------------------------------------------
Write-Host "[win] osquery (queries\windows\*.sql) -> $OutDir"

Get-ChildItem -Path $QueryDir -Filter *.sql | Sort-Object Name | ForEach-Object {
    $sql      = $_.FullName
    $baseName = $_.BaseName
    $out      = Join-Path $OutDir "$baseName.json"

    try {
        # Read as UTF-8 (PS 5.1 defaults to OEM/Windows-1252 which mangles
        # any non-ASCII chars in the .sql files) and strip SQL comment-only
        # lines + blanks. osqueryi treats a positional arg starting with `--`
        # as a CLI flag and fails, so the query we hand it must start with
        # the SELECT keyword.
        $queryLines = Get-Content -Encoding UTF8 $sql |
            Where-Object { $_ -notmatch '^\s*--' -and $_ -notmatch '^\s*$' }
        $query = ($queryLines -join "`n").Trim()

        # osqueryi writes glog warnings (W0525 ...) to stderr; capture stderr
        # separately so $rawJson is pure JSON for ConvertFrom-Json.
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $rawJson = & $Osqueryi --json $query 2>$errFile
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) {
                $stderr = ((Get-Content $errFile -Raw -ErrorAction SilentlyContinue) -replace "[`r`n]+", ' ')
                throw "osqueryi exit ${exitCode}: $stderr"
            }
        } finally {
            Remove-Item $errFile -ErrorAction SilentlyContinue
        }
        # Parse + re-emit so we guarantee array shape and UTF-8/LF.
        $parsed = $null
        if ($rawJson -and $rawJson.ToString().Trim() -ne '') {
            $parsed = $rawJson | ConvertFrom-Json -ErrorAction Stop
        }
        Write-JsonArrayFile -Path $out -Items $parsed
    } catch {
        Write-OutputFile $out "[]"
        $msg = $_.Exception.Message
        if (-not $msg) { $msg = $_.ToString() }
        $msg = $msg -replace "[`r`n]+", ' '
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
        Note-Error "$baseName.json" $msg
    }
}

# -----------------------------------------------------------------------------
# Supplementals
# -----------------------------------------------------------------------------
Write-Host "[win] supplementals"

# winget export - fully-versioned, importable list of installed packages.
try {
    $wingetOut = Join-Path $OutDir 'winget-export.json'
    & winget export -o $wingetOut --include-versions --accept-source-agreements 2>&1 | Out-Null
    if (-not (Test-Path $wingetOut)) { throw "winget export produced no file" }
} catch { Note-Error 'winget-export.json' $_.Exception.Message }

# winget source list
try {
    $srcOut = Join-Path $OutDir 'winget-sources.txt'
    $srcText = (& winget source list 2>&1 | Out-String)
    Write-OutputFile $srcOut $srcText
} catch { Note-Error 'winget-sources.txt' $_.Exception.Message }

# Windows capabilities (FoDs that are Installed)
try {
    $caps = Get-WindowsCapability -Online -ErrorAction Stop |
            Where-Object State -eq 'Installed' |
            Select-Object Name, State |
            Sort-Object Name
    Write-JsonArrayFile -Path (Join-Path $OutDir 'windows-capabilities.json') -Items $caps
} catch { Note-Error 'windows-capabilities.json' $_.Exception.Message }

# Windows optional features (Enabled only)
try {
    $feats = Get-WindowsOptionalFeature -Online -ErrorAction Stop |
             Where-Object State -eq 'Enabled' |
             Select-Object FeatureName |
             Sort-Object FeatureName
    Write-JsonArrayFile -Path (Join-Path $OutDir 'windows-features.json') -Items $feats
} catch { Note-Error 'windows-features.json' $_.Exception.Message }

# Defender - drop hash-y fields that bloat the diff and identify nothing.
try {
    $def = Get-MpComputerStatus -ErrorAction Stop |
           Select-Object -Property * -ExcludeProperty *Hash, *Hashes, *Signature*Version, *SignaturesLastUpdated*
    Write-JsonArrayFile -Path (Join-Path $OutDir 'defender-status.json') -Items @($def)
} catch { Note-Error 'defender-status.json' $_.Exception.Message }

# PowerShell modules
try {
    $mods = Get-Module -ListAvailable |
            Select-Object Name, Version, Path |
            Sort-Object Name, Version
    Write-JsonArrayFile -Path (Join-Path $OutDir 'powershell-modules.json') -Items $mods
} catch { Note-Error 'powershell-modules.json' $_.Exception.Message }

# Office Click-to-Run channel/version (if installed)
try {
    $officeKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
    if (Test-Path $officeKey) {
        $office = Get-ItemProperty $officeKey | Out-String
        Write-OutputFile (Join-Path $OutDir 'office-info.txt') $office
    } else {
        Write-OutputFile (Join-Path $OutDir 'office-info.txt') "Office Click-to-Run is not installed."
    }
} catch { Note-Error 'office-info.txt' $_.Exception.Message }

# GPU + monitors. Supplements osquery's video_info with driver date/version
# and decoded EDID-style monitor strings.
try {
    $vc = Get-CimInstance Win32_VideoController -ErrorAction Stop |
          Select-Object Name, DriverVersion, DriverDate, AdapterRAM, VideoProcessor,
                        CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate
    $mon = @()
    try {
        $mon = Get-CimInstance -Namespace root/wmi WmiMonitorID -ErrorAction Stop | ForEach-Object {
            $decode = {
                param($bytes)
                if ($null -eq $bytes) { return $null }
                ([System.Text.Encoding]::ASCII.GetString($bytes) -replace "`0", '').Trim()
            }
            [PSCustomObject]@{
                ManufacturerName  = & $decode $_.ManufacturerName
                ProductCodeID     = & $decode $_.ProductCodeID
                SerialNumberID    = & $decode $_.SerialNumberID
                UserFriendlyName  = & $decode $_.UserFriendlyName
                WeekOfManufacture = $_.WeekOfManufacture
                YearOfManufacture = $_.YearOfManufacture
                InstanceName      = $_.InstanceName
            }
        }
    } catch { Note-Error 'gpu-displays.json (monitors)' $_.Exception.Message }

    $gpu = [PSCustomObject]@{
        video_controllers = @($vc)
        monitors          = @($mon)
    }
    Write-JsonArrayFile -Path (Join-Path $OutDir 'gpu-displays.json') -Items @($gpu)
} catch { Note-Error 'gpu-displays.json' $_.Exception.Message }

# USB / HID / Audio / Camera / Bluetooth devices
try {
    $pnp = Get-PnpDevice -PresentOnly -ErrorAction Stop |
           Where-Object { $_.Class -in @('USB','HIDClass','AudioEndpoint','Camera','Bluetooth') } |
           Select-Object FriendlyName, Class, InstanceId, Manufacturer |
           Sort-Object Class, FriendlyName
    Write-JsonArrayFile -Path (Join-Path $OutDir 'usb-devices.json') -Items $pnp
} catch { Note-Error 'usb-devices.json' $_.Exception.Message }

# Active power plan
try {
    $pp = (& powercfg /getactivescheme 2>&1 | Out-String)
    Write-OutputFile (Join-Path $OutDir 'power-plan.txt') $pp
} catch { Note-Error 'power-plan.txt' $_.Exception.Message }

# Boot configuration - diffing this catches secure-boot or kernel param changes.
try {
    $bcd = (& bcdedit /enum 2>&1 | Out-String)
    Write-OutputFile (Join-Path $OutDir 'bcdedit.txt') $bcd
} catch { Note-Error 'bcdedit.txt' $_.Exception.Message }

# -----------------------------------------------------------------------------
# _summary.md
# -----------------------------------------------------------------------------
$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# Windows baseline capture - $Ts")
$summaryLines.Add('')
$summaryLines.Add("- Hostname: ``$(hostname)``")
$summaryLines.Add("- Windows: ``$([System.Environment]::OSVersion.VersionString)``")
$summaryLines.Add("- osquery: ``$OsqueryVer``")
$summaryLines.Add("- Capture finished: ``$((Get-Date).ToString('o'))``")
$summaryLines.Add('')
$summaryLines.Add('## Errors')
$summaryLines.Add('')
if ($Errors.Count -eq 0) {
    $summaryLines.Add('(none)')
} else {
    $Errors | ForEach-Object { $summaryLines.Add($_) }
}
$summaryLines.Add('')
$summaryLines.Add('## Files')
$summaryLines.Add('')
Get-ChildItem -File $OutDir | Sort-Object Name | ForEach-Object {
    $sz = '{0,8}' -f $_.Length
    $summaryLines.Add("- $($_.Name) - $sz bytes")
}

Write-OutputFile $Summary ($summaryLines -join "`n")

Write-Host "[win] done -> $OutDir (errors: $($Errors.Count))"
