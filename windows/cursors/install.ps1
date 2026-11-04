#Requires -Version 5.1
<#
.SYNOPSIS
    Install / uninstall the Everforest cursor scheme (Windows 11 Cursor Concept v2.2 recolor).

.DESCRIPTION
    One-shot installer: copies the cursor files into C:\Windows\Cursors, registers the
    scheme in HKCU, and activates it immediately (no sign-out needed).

    Prerequisites: local binaries must exist next to this script
        base\*.cur            15 static cursors (from the original pack)
        everforest\*.ani      2 animated cursors recolored to the Everforest accent
    Generate them first:  python generator/gen_cursor.py

    Elevation is requested automatically (needed for C:\Windows\Cursors).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
    .\install.ps1 -Uninstall      # back to the system default, remove the installed folder
#>
[CmdletBinding()]
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'

$Scheme   = 'W11 Cursors Light HDPI everforest by Jepri Creations'
$DstRoot  = Join-Path $env:WINDIR 'Cursors\W11_light_v2.2'
$DstBase  = Join-Path $DstRoot 'base'
$DstAni   = Join-Path $DstRoot 'everforest'
$SrcBase  = Join-Path $PSScriptRoot 'base'
$SrcAni   = Join-Path $PSScriptRoot 'everforest'

Add-Type -Namespace Native -Name U32 -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(int uiAction, int uiParam, IntPtr pvParam, int fWinIni);
'@

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-Cursors {
    # fWinIni must be 0 (or SENDCHANGE); passing SPIF_UPDATEINIFILE makes this call fail.
    if (-not [Native.U32]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 0)) {
        Write-Warning 'SPI_SETCURSORS failed; sign out and back in to apply.'
    }
}

function Restore-SystemDefault {
    $hkcu = [Microsoft.Win32.Registry]::CurrentUser
    $curs = $hkcu.CreateSubKey('Control Panel\Cursors')
    $curs.DeleteValue('', $false)              # empty -> panel shows the built-in scheme
    foreach ($k in 'Arrow', 'Help', 'AppStarting', 'Wait', 'crosshair', 'precisionhair', 'IBeam',
                   'Hand', 'NWPen', 'No', 'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW',
                   'SizeAll', 'UpArrow', 'Person', 'Pin') {
        $curs.DeleteValue($k, $false)          # absent -> falls back to the built-in default
    }
    $sch = $hkcu.CreateSubKey('Control Panel\Cursors\Schemes')
    $sch.DeleteValue($Scheme, $false)
    $curs.Close(); $sch.Close()
    Write-Host 'Restored the system default cursor scheme.'
}

# ---------------------------------------------------------------- elevate
if (-not (Test-Elevated)) {
    Write-Host 'Requesting administrator rights...'
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($Uninstall) { $argList += '-Uninstall' }
    try {
        Start-Process -FilePath $ps -ArgumentList $argList -Verb RunAs -Wait
    }
    catch {
        throw 'Elevation was cancelled; nothing was changed.'
    }
    return
}

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    Restore-SystemDefault
    Update-Cursors
    if (Test-Path $DstRoot) { Remove-Item $DstRoot -Recurse -Force }
    Write-Host "Removed $DstRoot"
    return
}

# ---------------------------------------------------------------- preflight
$missing = @()
foreach ($n in 'pointer.cur', 'help.cur', 'precision.cur', 'handwriting.cur', 'unavailable.cur',
               'vert.cur', 'horz.cur', 'dgn1.cur', 'dgn2.cur', 'move.cur',
               'alternate.cur', 'link.cur', 'beam.cur', 'pin.cur', 'person.cur') {
    if (-not (Test-Path (Join-Path $SrcBase $n))) { $missing += "base\$n" }
}
foreach ($n in 'working.ani', 'busy.ani') {
    if (-not (Test-Path (Join-Path $SrcAni $n))) { $missing += "everforest\$n" }
}
if ($missing.Count -gt 0) {
    $msg = "Missing cursor files: " + ($missing -join ', ')
    $msg += [Environment]::NewLine + 'Run "python generator/gen_cursor.py" first.'
    $msg += [Environment]::NewLine + 'Binaries are not stored in the repo: the original pack forbids redistribution.'
    throw $msg
}

# ---------------------------------------------------------------- copy
New-Item -ItemType Directory -Force -Path $DstBase, $DstAni | Out-Null
Copy-Item (Join-Path $SrcBase '*.cur') $DstBase -Force
Copy-Item (Join-Path $SrcAni  '*.ani') $DstAni  -Force
Write-Host ("Copied {0} .cur and {1} .ani to {2}" -f `
    (Get-ChildItem $DstBase -Filter *.cur).Count,
    (Get-ChildItem $DstAni  -Filter *.ani).Count, $DstRoot)

# ---------------------------------------------------------------- register
$b = $DstBase; $a = $DstAni
$map = [ordered]@{
    'Arrow'         = "$b\pointer.cur"
    'Help'          = "$b\help.cur"
    'AppStarting'   = "$a\working.ani"
    'Wait'          = "$a\busy.ani"
    'crosshair'     = "$b\precision.cur"
    'precisionhair' = "$b\precision.cur"
    'IBeam'         = "$b\beam.cur"
    'Hand'          = "$b\link.cur"
    'NWPen'         = "$b\handwriting.cur"
    'No'            = "$b\unavailable.cur"
    'SizeNS'        = "$b\vert.cur"
    'SizeWE'        = "$b\horz.cur"
    'SizeNWSE'      = "$b\dgn1.cur"
    'SizeNESW'      = "$b\dgn2.cur"
    'SizeAll'       = "$b\move.cur"
    'UpArrow'       = "$b\alternate.cur"
    'Person'        = "$b\person.cur"
    'Pin'           = "$b\pin.cur"
}

# The Schemes value is a comma list in the exact order of the 17 entries in the
# Mouse Properties panel.
$order = @(
    "$b\pointer.cur", "$b\help.cur", "$a\working.ani", "$a\busy.ani",
    "$b\precision.cur", "$b\beam.cur", "$b\handwriting.cur", "$b\unavailable.cur",
    "$b\vert.cur", "$b\horz.cur", "$b\dgn1.cur", "$b\dgn2.cur", "$b\move.cur",
    "$b\alternate.cur", "$b\link.cur", "$b\person.cur", "$b\pin.cur"
)

$hkcu = [Microsoft.Win32.Registry]::CurrentUser
$curs = $hkcu.CreateSubKey('Control Panel\Cursors')
$curs.SetValue('', $Scheme)
foreach ($k in $map.Keys) { $curs.SetValue($k, $map[$k]) }
$sch = $hkcu.CreateSubKey('Control Panel\Cursors\Schemes')
$sch.SetValue($Scheme, ($order -join ','))
$curs.Close(); $sch.Close()

Update-Cursors
Write-Host ("Installed: {0}" -f $Scheme) -ForegroundColor Green
Write-Host 'Check: Settings > Bluetooth & devices > Mouse > Additional mouse settings > Pointers.'
