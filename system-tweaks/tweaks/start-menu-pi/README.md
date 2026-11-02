# 开始菜单「所有应用」里的 Pi

> 在开始菜单的程序列表（Windows 11 的**所有应用**）里加入 **Pi**，
> 点击后用 **Windows Terminal** 打开 pwsh 并启动 `pi`。
> 启动方式与图标与右键菜单 [`Run Pi Here`](../../context-menu/README.md) 保持一致。

## 来源

- 归档日期：2026-09
- 实现：用户开始菜单 `Programs` 文件夹里的一个 `.lnk` 快捷方式（脚本生成）
- 脚本：[`add-start-menu-pi.ps1`](add-start-menu-pi.ps1)

## 为什么放 `.lnk` 就够

Windows 10/11 开始菜单的**所有应用**列表 = 下面两个目录里的快捷方式（加上 UWP/MSIX 应用）：

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs      ← 当前用户（本项目用这个）
%ProgramData%\Microsoft\Windows\Start Menu\Programs  ← 所有用户
```

所以往当前用户的 `Programs` 里丢一个 `Pi.lnk`，它就会出现在「所有应用」中，
也能被开始菜单搜索直接命中（搜索索引会索引该目录）。**无需管理员权限、不碰 HKLM**。

> ⚠️ 与「**已固定**（Pinned）」不是一回事：固定列表存在
> `%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start.bin`，
> 是**二进制私有格式**，没有官方接口可脚本化写入。想让 Pi 出现在固定区，需要**手动**右键 Pi → 固定到"开始"屏幕。

## 文件说明

| 文件 | 说明 |
|---|---|
| `add-start-menu-pi.ps1` | 创建/删除快捷方式（**UTF-8 with BOM**，PS 5.1 需要，勿存成无 BOM UTF-8） |

## 快捷方式内容

| 项 | 值 |
|---|---|
| 位置 | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Pi.lnk` |
| Target | `%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe` |
| Arguments | `-d "%USERPROFILE%" pwsh -NoExit -Command "pi"` |
| Start in | `%USERPROFILE%` |
| Icon | `<仓库>\context-menu\run-pi-here.ico,0` |

> `wt.exe` 走 Windows Terminal 的 **App Execution Alias**（`WindowsApps` 下的转发入口），
> 与右键菜单用的是同一个入口。
> `-NoExit` 让 pwsh 在 `pi` 退出后保留窗口；`-d` 指定起始目录为**用户主目录**。

## 当前状态

✅ **生效中**（2026-09-13 创建并自检，`Pi.lnk` 位于当前用户 `Programs`，
Target / Arguments / Icon 与上表一致）

本机实际写入的值：

```
Pi.lnk  → %APPDATA%\Roaming\Microsoft\Windows\Start Menu\Programs\Pi.lnk
Target  = wt.exe
Args    = -d "C:\Users\<YourName>" pwsh -NoExit -Command "pi"
Icon    = %USERPROFILE%\Projects\dotfiles\system-tweaks\context-menu\run-pi-here.ico,0
```

## 安装 / 重建

```powershell
# 创建（可重复执行，覆盖已有的 Pi.lnk）
cd %USERPROFILE%\Projects\dotfiles\system-tweaks\tweaks\start-menu-pi
.\add-start-menu-pi.ps1

# 预演（不落盘）
.\add-start-menu-pi.ps1 -WhatIf

# 换个名字 / 换图标
.\add-start-menu-pi.ps1 -ShortcutName 'Pi (agent)'
```

脚本结束会打印实际写入的快捷方式属性做自检。

## 验证

```powershell
# 1) 文件确实存在
Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Pi.lnk"

# 2) 属性确实是想要的（端到端核对的权威手段）
$sh = New-Object -ComObject WScript.Shell
$sh.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Pi.lnk") |
    Format-List TargetPath, Arguments, WorkingDirectory, IconLocation

# 3) 真的能跑：直接在「运行(Win+R)」或开始菜单点 Pi，
#    应弹出 Windows Terminal → pwsh 标签 → pi 交互界面
```

> 开始菜单有缓存：新建后可能**几秒到几十秒**才出现在「所有应用」里。
> 若迟迟不出现，重启 `explorer.exe`（任务管理器 → 重新启动）或注销重登。

## 卸载

```powershell
.\add-start-menu-pi.ps1 -Remove
# 等价于：
# Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Pi.lnk"
```

> 若曾手动「固定到开始屏幕」，记得右键取消固定，否则固定区会留下一个失效磁贴。

## ⚠️ 可移植性注意

`.lnk` 里的 **Icon 是写死的绝对路径**，与右键菜单项目同一个雷：

| 场景 | 后果 | 对策 |
|---|---|---|
| 移动 `system-tweaks` 仓库 | 图标变空白（Target 不受影响） | 移动后重跑 `add-start-menu-pi.ps1`（脚本按自身位置推导图标路径） |
| 换机器 / 换用户名 | Target、Args、Icon 全都要改 | 在新机器上直接跑脚本重建，不要把 `.lnk` 拷来拷去 |
| 升级 / 重装 Node（npm 全局） | 不影响——`pi` 通过 PATH 解析 | 无 |

> 💡 这也是本目录**只存脚本不存 `.lnk` 二进制**的原因：`.lnk` 内含绝对路径和机器相关信息，
> 不适合版本管理；脚本才是可重建的「权威源」。
