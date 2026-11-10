<#
  在 Windows 11 的右键“新建”菜单里：
    * 增加 Markdown / C / C++ / Python 四个空文件项
    * 去掉“BMP 图像”

  全部写在 HKCU 下，不需要管理员权限；用 remove-new-file-items.ps1 可撤销。

  ── 实测结论（本机 Win11 26100.9949，2026-11）─────────────────────────────
  Win11 的“新建”菜单由三部分拼成，缺一个都不显示：

  1) HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\
       Discardable\PostSetup\ShellNew  →  Classes (REG_MULTI_SZ)
     这是菜单项缓存列表，系统会自己往里加（我们加完 ShellNew 后 .md/.c/.cpp/.py
     自动出现在里面）。

  2)  HKCR\.<ext>\ShellNew             ← 必须挂在“扩展名键”这一层
     并且该扩展名必须有可用的默认 ProgID（关联了真实程序、有 shell\open\command），
     否则 ShellNew 会被静默忽略。
       * 挂在 HKCR\<ProgID>\ShellNew（扩展名键外面）→ 无效
       * 挂在 .<ext>\<ProgID>\ShellNew（Office 那种）→ 有效
       * 扩展名没有默认 ProgID → 无效（这就是 .md/.c/.cpp 一开始不出现的原因）

  3) UWP 应用也会贡献“新建”项，名字来自包资源，注册表 HKCR 里查不到：
       Microsoft.Paint     → ms-resource://Microsoft.Paint/Resources/ShellNewDisplayName_Bmp
       Microsoft.WindowsNotepad → .../ShellNewDisplayName_Txt
     解析后的字符串落在
       HKCU\Software\Classes\Local Settings\MrtCache\<...Microsoft.Paint...pri>\<hash>\<hash>
     把那个值清空，“BMP 图像”就从菜单里消失（本机实测重启 explorer 后保持）。
     注意 MrtCache 是缓存，Windows 重建它时可能恢复，重跑本脚本即可。
     该键路径超过 260 字符，必须逐级 OpenSubKey，不能一次传完整路径。
#>

$ErrorActionPreference = 'Stop'
$base = 'HKCU:\Software\Classes'

# ───────── 1) md / c / cpp：先关联 ProgID，再在扩展名层挂 ShellNew ─────────
$map = [ordered]@{
    '.md'  = 'VSCode.md'
    '.c'   = 'VSCode.c'
    '.cpp' = 'VSCode.cpp'
}

foreach ($ext in $map.Keys) {
    $progId = $map[$ext]
    if (-not (Test-Path -LiteralPath (Join-Path $base $progId))) {
        Write-Warning "$progId 不存在（没装 VS Code？），$ext 不会出现在新建菜单里"
        continue
    }
    # 关联（原先为空 = 双击弹“选择打开方式”）
    New-ItemProperty -Path (Join-Path $base $ext) -Name '(default)' `
        -Value $progId -PropertyType String -Force | Out-Null
    # ShellNew 必须挂在扩展名层
    $sn = Join-Path $base ($ext + '\ShellNew')
    New-Item -Path $sn -Force | Out-Null
    New-ItemProperty -Path $sn -Name 'NullFile' -Value '' -PropertyType String -Force | Out-Null
    Write-Host ("ok  {0} -> 关联 {1} + {0}\ShellNew (NullFile)" -f $ext, $progId)
}

# ───────── 2) py：已有 Python.File 关联，直接挂 ShellNew ─────────
$sn = Join-Path $base '.py\ShellNew'
New-Item -Path $sn -Force | Out-Null
New-ItemProperty -Path $sn -Name 'NullFile' -Value '' -PropertyType String -Force | Out-Null
Write-Host 'ok  .py -> .py\ShellNew (NullFile)，显示为“Python 文件”'

# ───────── 3) 去掉“BMP 图像”（清空 Paint 的 UWP 资源名）─────────
$cu = [Microsoft.Win32.Registry]::CurrentUser
$root = $cu.OpenSubKey('Software\Classes\Local Settings\MrtCache', $true)
if (-not $root) {
    Write-Warning '打不开 MrtCache，跳过移除“BMP 图像”'
} else {
    $script:hits = 0
    function Clear-BmpDisplayName($key) {
        foreach ($v in $key.GetValueNames()) {
            if ($v -like '*ShellNewDisplayName_Bmp*') {
                $key.SetValue($v, '', [Microsoft.Win32.RegistryValueKind]::String)
                $script:hits++
            }
        }
        foreach ($n in $key.GetSubKeyNames()) {
            $sk = $null
            try { $sk = $key.OpenSubKey($n, $true) } catch { }
            if (-not $sk) { try { $sk = $key.OpenSubKey($n) } catch { } }
            if ($sk) { Clear-BmpDisplayName $sk; $sk.Close() }
        }
    }
    Clear-BmpDisplayName $root
    $root.Close()
    Write-Host ("ok  清空 {0} 处 ShellNewDisplayName_Bmp，BMP 图像已从新建菜单移除" -f $script:hits)
}
