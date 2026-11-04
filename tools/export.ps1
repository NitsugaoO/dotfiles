#requires -Version 5.1
<#
.SYNOPSIS
    从两个私有上游仓库导出成品配置到本仓库（只读发布镜像的同步入口）。

.DESCRIPTION
    上游（作者私有，未公开）：
        $env:USERPROFILE\Themes               → everforest-themes：色板 + 生成器 + 主题产物
        $env:USERPROFILE\Projects\my_dot      → dotfiles（glazewm / yasb / wsl）+ system-tweaks

    本仓库 = 成品快照，不含 generator/src/wallpapers，也不含本机私有信息。
    导出完会自动调用 tools\sanitize.py 做路径/账号清洗。

    自己的仓库想复用这套配置，不需要跑这个脚本 —— 直接拿现有文件就行。

.EXAMPLE
    .\tools\export.ps1              # 导出 + 清洗
    .\tools\export.ps1 -WhatIf      # 只看会拷哪些文件
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $PSScriptRoot
$themes  = Join-Path $env:USERPROFILE 'Themes'
$mydot   = Join-Path $env:USERPROFILE 'Projects\my_dot'

foreach ($p in @($themes, $mydot)) {
    if (-not (Test-Path $p)) { throw "找不到上游仓库: $p" }
}

# 源路径（相对上游根）→ 目标路径（相对本仓库根）
$fromThemes = @(
    @{ S = 'themes\everforest\tokens.yaml';                          D = 'palette\tokens.yaml' }

    @{ S = 'themes\everforest\Yasb\styles.css';                      D = 'windows\yasb\styles.css' }

    @{ S = 'themes\everforest\StartMenu\everforest-theme.yaml';      D = 'windows\windhawk\start-menu\everforest-theme.yaml' }
    @{ S = 'themes\everforest\StartMenu\README.md';                  D = 'windows\windhawk\start-menu\README.md' }
    @{ S = 'themes\everforest\StartMenu\everforest-theme-classic.yaml'; D = 'windows\windhawk\start-menu-classic\everforest-theme-classic.yaml' }

    @{ S = 'themes\everforest\Taskbar\everforest-theme.yaml';        D = 'windows\windhawk\taskbar\everforest-theme.yaml' }
    @{ S = 'themes\everforest\Taskbar\README.md';                    D = 'windows\windhawk\taskbar\README.md' }

    @{ S = 'themes\everforest\Notification\everforest-theme.yaml';   D = 'windows\windhawk\notification\everforest-theme.yaml' }
    @{ S = 'themes\everforest\Notification\README.md';               D = 'windows\windhawk\notification\README.md' }

    @{ S = 'themes\everforest\Terminal\windows-terminal.json';       D = 'windows\terminal\windows-terminal.json' }
    @{ S = 'themes\everforest\Terminal\README.md';                   D = 'windows\terminal\README.md' }

    @{ S = 'themes\everforest\Explorer\everforest-theme.yaml';       D = 'windows\windhawk\explorer\everforest-theme.yaml' }
    @{ S = 'themes\everforest\Explorer\README.md';                   D = 'windows\windhawk\explorer\README.md' }

    @{ S = 'themes\everforest\Windhawk\translucent-windows.yaml';    D = 'windows\windhawk\translucent-windows\translucent-windows.yaml' }

    @{ S = 'themes\everforest\Everything\everforest-theme-command.txt';      D = 'windows\everything\everforest-theme-command.txt' }
    @{ S = 'themes\everforest\Everything\everforest-theme-command-core.txt'; D = 'windows\everything\everforest-theme-command-core.txt' }
    @{ S = 'themes\everforest\Everything\README.md';                 D = 'windows\everything\README.md' }

    @{ S = 'themes\everforest\TackyBorders\config.yaml';             D = 'windows\tacky-borders\config.yaml' }
    @{ S = 'themes\everforest\TackyBorders\README.md';               D = 'windows\tacky-borders\README.md' }

    # 光标：只导出脚本与安装件（*.cur / *.ani 受原包 Agreement 限制不入库）
    @{ S = 'themes\everforest\Cursors\README.md';                    D = 'windows\cursors\README.md' }
    @{ S = 'themes\everforest\Cursors\Install.inf';                  D = 'windows\cursors\Install.inf' }
    @{ S = 'themes\everforest\Cursors\install.ps1';                  D = 'windows\cursors\install.ps1' }

    @{ S = 'themes\everforest\Edge\manifest.json';                   D = 'windows\edge\manifest.json' }
    @{ S = 'themes\everforest\Edge\Cached Theme.pak';                D = 'windows\edge\Cached Theme.pak' }
    @{ S = 'themes\everforest\Edge\README.md';                       D = 'windows\edge\README.md' }

    @{ S = 'themes\everforest\Pi\everforest.json';                   D = 'editors\pi\everforest.json' }
    @{ S = 'themes\everforest\Pi\README.md';                         D = 'editors\pi\README.md' }

    @{ S = 'themes\everforest\ClashParty\everforest.css';            D = 'apps\clash-party\everforest.css' }
    @{ S = 'themes\everforest\ClashParty\README.md';                 D = 'apps\clash-party\README.md' }

    @{ S = 'nvim\init.vim';                                          D = 'editors\nvim\init.vim' }
    @{ S = 'nvim\colors\everforest.lua';                             D = 'editors\nvim\colors\everforest.lua' }
    @{ S = 'nvim\README.md';                                         D = 'editors\nvim\README.md' }
)

$fromMydot = @(
    @{ S = 'dotfiles\glazewm\config.yaml';                           D = 'windows\glazewm\config.yaml' }
    @{ S = 'dotfiles\glazewm\launch-glazewm.vbs';                    D = 'windows\glazewm\launch-glazewm.vbs' }
    @{ S = 'dotfiles\glazewm\README.md';                             D = 'windows\glazewm\README.md' }

    @{ S = 'dotfiles\yasb\config.yaml';                              D = 'windows\yasb\config.yaml' }
    @{ S = 'dotfiles\yasb\README.md';                                D = 'windows\yasb\README.md' }
    @{ S = 'dotfiles\yasb\scripts\obs_status.py';                    D = 'windows\yasb\scripts\obs_status.py' }
    @{ S = 'dotfiles\yasb\scripts\obs_action.py';                    D = 'windows\yasb\scripts\obs_action.py' }
    @{ S = 'dotfiles\yasb\patches\install_patches.py';               D = 'windows\yasb\patches\install_patches.py' }
    @{ S = 'dotfiles\yasb\patches\status_icons.py';                  D = 'windows\yasb\patches\status_icons.py' }

    @{ S = 'dotfiles\wsl\bin\ida';                                   D = 'wsl\bin\ida' }
    @{ S = 'dotfiles\wsl\bin\here';                                  D = 'wsl\bin\here' }
    @{ S = 'dotfiles\wsl\gdb\gdbinit';                               D = 'wsl\gdb\gdbinit' }
    @{ S = 'dotfiles\wsl\gdb\pane.sh';                               D = 'wsl\gdb\pane.sh' }
    @{ S = 'dotfiles\wsl\gdb\pwndbg-ctx-split.gdb';                  D = 'wsl\gdb\pwndbg-ctx-split.gdb' }
    @{ S = 'dotfiles\wsl\tmux\tmux.conf';                            D = 'wsl\tmux\tmux.conf' }
    @{ S = 'dotfiles\wsl\README.md';                                 D = 'wsl\README.md' }
)

# 需要整目录同步的（system-tweaks 全量 + VSCode 扩展）
$trees = @(
    @{ Root = $themes; S = 'extensions\everforest-hard'; D = 'extensions\everforest-hard' }
    @{ Root = $mydot;  S = 'system-tweaks';               D = 'system-tweaks' }
)

# 发布版本里刻意不含的（本机快照 / 一次性产物）
$excluded = @(
    'system-tweaks\tweaks\glazewm-startup\HKCU-Run-20260913-005910.reg'
    'system-tweaks\tweaks\desktop-icons-toggle\patch_desktop_toggle_mod.py'
    'system-tweaks\tweaks\desktop-icons-toggle\desktop-icons-double-click-toggle2-original-v1.1.wh.cpp'
)

$count = 0

function Copy-One([string]$srcRoot, $item) {
    $src = Join-Path $srcRoot $item.S
    $dst = Join-Path $root $item.D
    if (-not (Test-Path $src)) { Write-Warning "跳过（源不存在）: $($item.S)"; return }
    if ($PSCmdlet.ShouldProcess($item.D, '导出')) {
        $dir = Split-Path $dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item $src $dst -Force
        Write-Host "  [OK] $($item.S) -> $($item.D)"
        $script:count++
    }
}

foreach ($item in $fromThemes) { Copy-One $themes $item }
foreach ($item in $fromMydot)  { Copy-One $mydot  $item }

foreach ($tree in $trees) {
    $src = Join-Path $tree.Root $tree.S
    $dst = Join-Path $root $tree.D
    if (-not (Test-Path $src)) { Write-Warning "跳过（源不存在）: $($tree.S)"; continue }
    if ($PSCmdlet.ShouldProcess($tree.D, '镜像目录')) {
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
        Copy-Item (Join-Path $src '*') $dst -Recurse -Force
        Write-Host "  [DIR] $($tree.S) -> $($tree.D)"
        $count++
    }
}

foreach ($rel in $excluded) {
    $p = Join-Path $root $rel
    if (Test-Path $p) {
        if ($PSCmdlet.ShouldProcess($rel, '移除（发布版本不含）')) {
            Remove-Item $p -Force
            Write-Host "  [DEL] $rel"
        }
    }
}

Write-Host "`n导出 $count 项。" -ForegroundColor Cyan

if (-not $WhatIfPreference) {
    Write-Host "`n开始清洗路径 / 账号…" -ForegroundColor Cyan
    python (Join-Path $PSScriptRoot 'sanitize.py')
    Write-Host "完成。请用 git diff 复核后再提交。" -ForegroundColor Green
}
