#Requires -RunAsAdministrator
<#
    desktop-icons-double-click-toggle2 v1.4 部署脚本

    做了什么：
      1. 备份现有 mod DLL 与注册表键
      2. 用 Windhawk 自带 clang 编译 v1.4 源码（参数从 Windhawk UI 的编译逻辑复刻）
      3. DLL 落到 Engine\Mods\64，源码同步到 ModsSource 与 EditorWorkspace
      4. 改写注册表 LibraryFileName / Version
      5. （可选）-RestartService 重启 Windhawk 服务让新 DLL 立即生效

    注意：必须 UTF-8 with BOM 保存，PowerShell 5.1 否则按 GBK 解析中文会语法错误。
#>
param(
    [switch]$RestartService
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcFile    = Join-Path $root 'desktop-icons-double-click-toggle2.wh.cpp'
$windhawk   = 'C:\Program Files\Windhawk'
$compiler   = Join-Path $windhawk 'Compiler'
$engineMods = 'C:\ProgramData\Windhawk\Engine\Mods\64'
$modsSource = 'C:\ProgramData\Windhawk\ModsSource'
$editorWs   = 'C:\ProgramData\Windhawk\EditorWorkspace'
$backupDir  = 'C:\ProgramData\Windhawk\Engine\ModsWritable'

$modId   = 'local@desktop-icons-double-click-toggle2'
$version = '1.4'
$seq     = Get-Random -Minimum 100000 -Maximum 999999
$dllName = '{0}_{1}_{2}.dll' -f $modId, $version, $seq

function Fail($msg) { Write-Host "错误：$msg" -ForegroundColor Red; exit 1 }
function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

if (-not (Test-Path $srcFile)) { Fail "找不到源码：$srcFile" }
if (-not (Test-Path (Join-Path $compiler 'bin\clang++.exe'))) { Fail '找不到 Windhawk 自带 clang' }

# windhawk.lib 随 Engine 版本变化，自动找最新的 64 位目录
$lib = Get-ChildItem (Join-Path $windhawk 'Engine') -Directory |
    Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } -Descending |
    ForEach-Object { Join-Path $_.FullName '64\windhawk.lib' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $lib) { Fail '找不到 windhawk.lib' }
Step "使用 $lib"

# ---------- 1. 备份 ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Step "备份到 $backupDir"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
& reg.exe export "HKLM\SOFTWARE\Windhawk\Engine\Mods\$modId" (Join-Path $backupDir "backup-$modId-$stamp.reg") /y | Out-Null
if ($LASTEXITCODE -ne 0) { Fail '注册表导出失败' }

$oldDll = Get-ChildItem $engineMods -Filter "$modId*.dll" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($oldDll) { Copy-Item $oldDll.FullName (Join-Path $backupDir "$($oldDll.Name).$stamp.bak") -Force }

# ---------- 2. 编译 ----------
$outDll = Join-Path $engineMods $dllName
Step "编译 $dllName"
$clangArgs = @(
    '-std=c++23', '-O2', '-shared', '-DUNICODE', '-D_UNICODE',
    '-DWINVER=0x0A00', '-D_WIN32_WINNT=0x0A00', '-D_WIN32_IE=0x0A00',
    '-DNTDDI_VERSION=0x0A000008', '-D__USE_MINGW_ANSI_STDIO=0', '-DWH_MOD',
    '-DWH_MOD_ID=L"desktop-icons-double-click-toggle2"',
    '-DWH_MOD_VERSION=L"' + $version + '"',
    $lib,
    '-x', 'c++', $srcFile,
    '-include', 'windhawk_api.h',
    '-target', 'x86_64-w64-mingw32',
    '-Wl,--export-all-symbols',
    '-o', $outDll,
    '-lcomctl32'
)
& (Join-Path $compiler 'bin\clang++.exe') @clangArgs
if ($LASTEXITCODE -ne 0) { Fail '编译失败' }
if (-not (Test-Path $outDll)) { Fail '编译产物不存在' }
Step ("DLL 已生成：{0} ({1} 字节)" -f $dllName, (Get-Item $outDll).Length)

# ---------- 3. 同步源码 ----------
Step '同步源码到 ModsSource / EditorWorkspace'
Copy-Item $srcFile (Join-Path $modsSource "$modId.wh.cpp") -Force
Copy-Item $srcFile (Join-Path $editorWs 'mod.wh.cpp') -Force

# ---------- 4. 写注册表 ----------
Step "写注册表 LibraryFileName=$dllName, Version=$version"
$key = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$modId"
Set-ItemProperty -Path $key -Name 'LibraryFileName' -Value $dllName -Type String
Set-ItemProperty -Path $key -Name 'Version' -Value $version -Type String
Set-ItemProperty -Path $key -Name 'SettingsChangeTime' -Value ([int][double]::Parse((Get-Date -UFormat %s))) -Type DWord

# ---------- 5. 生效 ----------
if ($RestartService) {
    Step '重启 Windhawk 服务'
    Restart-Service -Name Windhawk -Force
    Start-Sleep -Seconds 3
    Write-Host '已完成。' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host '文件与注册表已就绪，但新 DLL 还没被加载。' -ForegroundColor Yellow
    Write-Host '任选一种让它生效：' -ForegroundColor Yellow
    Write-Host '  a) 打开 Windhawk -> 该 mod -> 关闭再启用（最省事）'
    Write-Host '  b) 或重跑本脚本并加 -RestartService（会重启 Windhawk 服务，所有 mod 短暂重载）'
}
