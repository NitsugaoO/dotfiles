# 删除 Excel / PowerPoint 的“新建”项（PowerShell 需以管理员身份运行）
# 只删 ShellNew 子键：不影响双击打开 .xlsx/.pptx，也不影响模板本身。
$ErrorActionPreference = 'Stop'
foreach ($p in 'HKLM:\SOFTWARE\Classes\.xlsx\Excel.Sheet.12\ShellNew',
               'HKLM:\SOFTWARE\Classes\.pptx\PowerPoint.Show.12\ShellNew') {
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Recurse -Force
        Write-Host "removed $p"
    } else {
        Write-Host "already gone: $p"
    }
}
