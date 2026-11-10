<#
  撤销 add-new-file-items.ps1：
    * 删除 .md / .c / .cpp / .py 的 ShellNew
    * 清空 .md / .c / .cpp 的默认 ProgID（恢复“双击弹选择打开方式”）
    * 把“BMP 图像”名称恢复回 MrtCache
#>

$ErrorActionPreference = 'SilentlyContinue'
$base = 'HKCU:\Software\Classes'

foreach ($ext in '.md', '.c', '.cpp', '.py') {
    $sn = Join-Path $base ($ext + '\ShellNew')
    if (Test-Path -LiteralPath $sn) {
        Remove-Item -LiteralPath $sn -Recurse -Force
        Write-Host "removed $ext\ShellNew"
    }
}

foreach ($ext in '.md', '.c', '.cpp') {
    $p = Join-Path $base $ext
    if (Test-Path -LiteralPath $p) {
        Remove-ItemProperty -Path $p -Name '(default)' -Force
        Write-Host "cleared default ProgID of $ext"
    }
}

# 恢复“BMP 图像”
$cu = [Microsoft.Win32.Registry]::CurrentUser
$root = $cu.OpenSubKey('Software\Classes\Local Settings\MrtCache', $true)
if ($root) {
    $script:hits = 0
    function Restore-BmpDisplayName($key) {
        foreach ($v in $key.GetValueNames()) {
            if ($v -like '*ShellNewDisplayName_Bmp*') {
                $key.SetValue($v, 'BMP 图像', [Microsoft.Win32.RegistryValueKind]::String)
                $script:hits++
            }
        }
        foreach ($n in $key.GetSubKeyNames()) {
            $sk = $null
            try { $sk = $key.OpenSubKey($n, $true) } catch { }
            if (-not $sk) { try { $sk = $key.OpenSubKey($n) } catch { } }
            if ($sk) { Restore-BmpDisplayName $sk; $sk.Close() }
        }
    }
    Restore-BmpDisplayName $root
    $root.Close()
    Write-Host ("restored {0} ShellNewDisplayName_Bmp value(s)" -f $script:hits)
}
