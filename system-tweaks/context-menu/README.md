# 资源管理器右键「Run Pi Here」

> 在**文件夹**、**驱动器**、**文件夹空白处**的右键菜单加入「Run Pi Here」，
> 点击后在该目录用 Windows Terminal 打开 pwsh 并启动 `pi`。

> 📁 同目录下还有「新建」子菜单定制（加 Markdown/C/C++/Python，去掉 BMP/Excel/PPT）：
> [`new-file-items/README.md`](new-file-items/README.md)

## 来源

- 归档日期：2026-09
- 实现：HKCU 注册表（`Run-Pi-Here.reg` 导入）+ 配套图标 `run-pi-here.ico`

## 文件说明

| 文件 | 说明 |
|---|---|
| `Run-Pi-Here.reg` | 注册表导入文件，**UTF-16LE 编码**（注册表编辑器默认格式，勿存成 UTF-8） |
| `run-pi-here.ico` | 右键菜单项图标 |

## 注册表位置

全部位于 `HKCU\Software\Classes`（仅当前用户，无需管理员权限），共 **3 处**：

```
HKCU\Software\Classes\Directory\Background\shell\RunPiHere    ← 文件夹空白处
HKCU\Software\Classes\Directory\shell\RunPiHere               ← 文件夹上
HKCU\Software\Classes\Drive\shell\RunPiHere                   ← 驱动器上
```

三处内容一致：

| 值 | 内容 |
|---|---|
| `(默认)` | `Run Pi Here` |
| `Icon` | `<仓库>\system-tweaks\context-menu\run-pi-here.ico` |
| `command\(默认)` | `"<...>\wt.exe" -d "%V" pwsh -NoExit -Command "pi"` |

> `%V` = 被右键的目录/驱动器；`wt.exe` = Windows Terminal；`pwsh` = PowerShell 7。
> 使用 `-NoExit` 让窗口在 pi 退出后保留。

## 当前状态

✅ **生效中**（2026-09 验证：三处注册表项均存在，值与本目录的 `.reg` 一致）

本机实际写入的值：

```
Icon    = %USERPROFILE%\Projects\dotfiles\system-tweaks\context-menu\run-pi-here.ico
Command = "wt.exe" -d "%V" pwsh -NoExit -Command "pi"
```

> 📌 **2026-09-13 迁移记录**：本目录从 `~/.pi/my-plugins/system-tweaks/` 迁至
> `~/Projects/system-tweaks/`。由于 `Icon` 是**写死的绝对路径**，迁移后三处注册表项
> 图标全部失效，已更新为新路径（`.reg` 文件同步修正）。
> 详见 [`../README.md`](../README.md) 的「踩坑速查」。

## 安装 / 重建

```powershell
# 导入（HKCU，无需管理员）
reg import ".\Run-Pi-Here.reg"

# 验证
Get-ItemProperty 'HKCU:\Software\Classes\Directory\shell\RunPiHere'
Get-ItemProperty 'HKCU:\Software\Classes\Directory\shell\RunPiHere\command'
```

## 卸载

```powershell
Remove-Item -Recurse 'HKCU:\Software\Classes\Directory\Background\shell\RunPiHere'
Remove-Item -Recurse 'HKCU:\Software\Classes\Directory\shell\RunPiHere'
Remove-Item -Recurse 'HKCU:\Software\Classes\Drive\shell\RunPiHere'
```

## ⚠️ 可移植性注意

`.reg` 是静态文件，其中两处路径写死了 `C:\Users\<YourName>`：**图标路径**、**`wt.exe` 路径**。
换机器或移动仓库后需先改 `.reg` 再重新导入：

| 原值 | 可移植写法 |
|---|---|
| `%USERPROFILE%\Projects\dotfiles\system-tweaks\...\run-pi-here.ico` | `%USERPROFILE%\Projects\system-tweaks\...\run-pi-here.ico`（需 `REG_EXPAND_SZ` 类型才会展开） |
| `wt.exe` | 若 `wt.exe` 已在 PATH，可直接写 `wt.exe` |

> 上方「当前状态」保留的是本机**实际写入**的绝对路径，便于排查时对照。
