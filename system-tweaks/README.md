# system-tweaks —— Windows 系统定制归档

记录对 Windows 系统级行为的自定义配置（注册表右键菜单、文件关联、桌面交互、开机自启等）。
每个项目一份文档，附**实现路径 + 当前状态 + 踩坑记录**，方便日后重建、排查或继续改动。

## 位置说明

> 📍 本目录于 **2026-09-13** 从 `~/.pi/my-plugins/system-tweaks/` **迁移至** `~/Projects/system-tweaks/`。

**迁移原因**：它是 Windows 系统定制归档，与 pi 插件仓库（`my-plugins`）定位无关，
放在一起造成「归属错位」——想看一件事要在两个仓库之间跳。

**⚠️ 迁移的副作用（已修复）**：`context-menu` 的图标路径是**写死在注册表里**的绝对路径，
迁移后三处 `RunPiHere` 的 `Icon` 值全部失效（指向旧的 `my-plugins` 路径）。
已更新为 `%USERPROFILE%\Projects\dotfiles\system-tweaks\...`，`.reg` 文件同步修正。

> 💡 **教训**：注册表值里的绝对路径是**移动仓库时最容易踩的雷**。
> 迁移任何被注册表引用的目录后，务必回查 `Icon`、`command` 之类的值。

## 目录结构

```
~/Projects/system-tweaks/
├── README.md                        ← 本索引
├── context-menu/                    ← 资源管理器右键菜单
│   ├── README.md
│   ├── Run-Pi-Here.reg              ← 注册表导入文件（UTF-16LE）
│   ├── run-pi-here.ico
│   └── new-file-items/              ← 「新建」子菜单：加 md/c/cpp/py，去 BMP/Excel/PPT
│       ├── README.md
│       ├── add-new-file-items.ps1       ← 一键应用（加 4 项 + 去 BMP）
│       ├── remove-new-file-items.ps1    ← 一键撤销
│       ├── remove-office-new-items.ps1  ← 去 Excel/PPT（需管理员）
│       ├── dump-new-menu.ps1            ← 诊断：不开界面直接读菜单内容
│       └── backup-office-shellnew/      ← 删除前的 ShellNew 原键（.reg 可恢复）
└── tweaks/
    ├── py-rightclick-run/           ← .py 右键「用 Python 运行」
    │   └── README.md
    ├── desktop-icons-toggle/        ← 双击桌面切换图标显示/隐藏
    │   ├── README.md
    │   ├── desktop-icons-double-click-toggle2.wh.cpp            ← 修改版 mod 源码
    │   ├── desktop-icons-double-click-toggle2-original-v1.1.wh.cpp  ← 原始版（对比用）
    │   └── patch_desktop_toggle_mod.py                          ← 补丁脚本
    ├── start-menu-pi/               ← 开始菜单「所有应用」加入 Pi
    │   ├── README.md
    │   └── add-start-menu-pi.ps1    ← 生成 Pi.lnk（UTF-8 BOM）
    ├── glazewm-startup/             ← GlazeWM 提前自启（绕开 explorer 启动队列）
    │   ├── README.md
    │   ├── launch-glazewm.vbs       ← 启动包装脚本（副本）
    │   ├── GlazeWM-task.xml         ← 计划任务定义导出（含 Delay=PT15S）
    │   └── HKCU-Run-*.reg           ← 改造前的 Run 键备份
    ├── onedrive-uninstall/          ← 卸载 OneDrive
    │   └── README.md
    └── razer-synapse-autostart/     ← 关闭雷蛇 Synapse 开机自启
        ├── README.md
        └── restore-razer-autostart.reg   ← 还原自启（UTF-16LE）
```

## 索引

| 项目 | 状态 | 实现方式 | 文档 |
|---|---|---|---|
| 资源管理器右键「Run Pi Here」 | ✅ 生效中 | HKCU 注册表（`.reg` 导入）+ Windows Terminal | [`context-menu/README.md`](context-menu/README.md) |
| 右键「新建」加 md/c/cpp/py、去 BMP/Excel/PPT | ✅ 生效中 | 扩展名层 `ShellNew`（需有 ProgID 关联）+ MrtCache 清名；Excel/PPT 删 HKLM `ShellNew` | [`context-menu/new-file-items/`](context-menu/new-file-items/README.md) |
| .py 右键「用 Python 运行」 | ✅ 生效中 | HKCU 注册表 + scoop python | [`tweaks/py-rightclick-run/`](tweaks/py-rightclick-run/README.md) |
| 开始菜单「所有应用」加入 Pi | ✅ 生效中 | 用户开始菜单 `Programs` 下的 `.lnk`（脚本生成） | [`tweaks/start-menu-pi/`](tweaks/start-menu-pi/README.md) |
| 双击桌面切换图标显示/隐藏 | ✅ 生效中 | Windhawk mod（非 AHK） | [`tweaks/desktop-icons-toggle/`](tweaks/desktop-icons-toggle/README.md) |
| GlazeWM 提前自启（登录后延迟 15s） | ✅ 生效中 | 计划任务（登录触发 + `Delay=PT15S`）+ wscript 包装 | [`tweaks/glazewm-startup/`](tweaks/glazewm-startup/README.md) |
| 卸载 OneDrive | ✅ 已卸载 | `OneDriveSetup.exe /uninstall` | [`tweaks/onedrive-uninstall/`](tweaks/onedrive-uninstall/README.md) |
| 关闭雷蛇 Synapse 开机自启 | ✅ 生效中（待重启验证） | HKCU 注册表**两处**：删 Run 项 + `StartupApproved\Run` 写禁用位 | [`tweaks/razer-synapse-autostart/`](tweaks/razer-synapse-autostart/README.md) |

---

## ⚡ 踩坑速查（跨项目汇总）

改动系统级配置时的通用雷区，按「症状 → 原因 → 对策」整理：

| 症状 | 原因 | 对策 |
|---|---|---|
| **移动仓库后图标变空白** | 注册表 `Icon`/`command` 写死了绝对路径 | 迁移后回查注册表值；新写入优先用 `%USERPROFILE%` + `REG_EXPAND_SZ` |
| **计划任务返回 `2147943140`** | 十进制换算 = `0x800702E4` → Win32 **740 ERROR_ELEVATION_REQUIRED**；目标 exe 的 manifest 带 `uiAccess="true"`，`LeastPrivilege` 令牌直连被拒 | 用 `wscript.exe`（或 `cmd.exe`）**中转**启动，保持非提权 |
| **改了计划任务 `RunLevel` 报「拒绝访问」** | `Highest` 需要管理员权限 | 多数场景**不需要**提权，保持 `Limited` |
| **登录触发器的程序开机必崩** | `Delay=0` 在登录瞬间启动，shell / DWM / COM 尚未就绪，程序早期初始化 `abort()`（表现为 `ucrtbase.dll` / `0xc0000409` + 异常数据 `7`）；且**任务仍返回 `0`**（包装脚本 `Run ...,0,False` 不等待，返回 0 不代表程序活着） | 给 `LogonTrigger` 加 `Delay`（如 `PT15S`）。**「尽早」要有下限**；排查时别只看 `LastTaskResult`，要查事件日志 + 进程存活 |
| **卸载软件后开机又回来了** | 只删了 Run 项，漏了**登录触发的计划任务** | 一并检查 `Get-ScheduledTask` 里的 `LogonTrigger` 项 |
| **删了 Run 项，程序又自己写回来** | 程序自带的「自启」状态存在别处（IndexedDB / 服务端 / 内部配置），启动时重写 Run 项 | **别硬刚内部状态**（改不动、会被覆盖）；在 `HKCU\...\Explorer\StartupApproved\Run` 写 `03`（禁用）兜底 —— 这才是任务管理器「禁用」的真实机制，Windows 层直接跳过 |
| **不确定 `StartupApproved\Run` 的二进制值该写什么** | 该格式无官方文档 | 从本机已有条目**反推**：`02 00 00 00 …` = 启用，`03 00 00 00 …` = 禁用（12 字节，可带 8 字节 FILETIME 时间戳）；`reg export` 可复核 |
| **Git Bash 里 `reg.exe` 报「无效语法…REG EXPORT /?」** | MSYS 把 `/y`、`/v`、`/f` 当成路径参数转换 | 改用 **PowerShell 原生 cmdlet**（`Remove-ItemProperty` / `New-ItemProperty`），或给命令加 `MSYS_NO_PATHCONV=1` 前缀 |
| **卸载后文件删不干净** | Shell 扩展 `.dll` 被 `explorer.exe` 占用，排入 `PendingFileRenameOperations` | **正常现象，重启后自动清理** |
| **以为 yasb 被重复启动** | yasb 常驻**两个进程**（父子关系）是正常架构 | 用 `Win32_Process` 查 `ParentProcessId` 再下结论 |
| **PowerShell `New-Item` 建深层注册表键反复失败** | PS 对深层键的怪癖 | 改用 **`.reg` 文件 + `reg import`** |
| **`.reg` 中文乱码** | 编码非 UTF-16LE（注册表编辑器默认格式） | 存成 **UTF-16LE**（带 BOM） |
| **开始菜单里新建的快捷方式不出现** | 开始菜单有缓存（几秒~几十秒） | 稍等，或重启 `explorer.exe` / 注销重登；不要靠「改注册表」硬刷 |
| **想脚本化把程序固定到开始屏幕** | 固定区是 `start.bin` **二进制私有格式**，无官方接口 | 只能**手动**右键 → 固定；脚本化能做的只是让它出现在「所有应用」 |
| **不确定某个 tweak 到底生效没** | 只看了「配置存在」 | 用文档里的**验证方法**做端到端测试（杀进程重来 / 查实际值） |
| **加了 `ShellNew` 但「新建」菜单没反应** | ① 挂错层：必须在 `HKCR\.<ext>\ShellNew`，写在 `HKCR\<ProgID>\ShellNew`（扩展名键外面）无效；② 该扩展名没有可用默认 ProgID（无 `shell\open\command`），`ShellNew` 被静默忽略 | 先给扩展名关联真实程序，再把 `ShellNew` 挂到扩展名键下；详见 [`context-menu/new-file-items/README.md`](context-menu/new-file-items/README.md) |
| **注册表里怎么都搜不到某项，菜单里却有**（如「BMP 图像」「文本文档」） | 来自 Store 应用（画图 / 记事本）的资源名，缓存在 `HKCU\...\Local Settings\MrtCache\<pkg>.pri\...`，值名形如 `@{...ms-resource://.../ShellNewDisplayName_Bmp}` | 清空该值的**数据**；键路径 >260 字符，必须逐级 `OpenSubKey` |
| **32 位进程里查注册表，`.txt`/`.bmp` 的键「不存在」** | 32 位进程看到的 `HKCR` 是 Wow6432Node 合并视图 | 用 64 位 PowerShell 或 `.NET` 的 `Registry.ClassesRoot` |

## 通用原则

- **仅当前用户（HKCU）**：系统级配置尽量走 `HKCU\Software\Classes`，无需管理员权限、不污染 HKLM。
- **路径用 scoop `current` 链接**：`scoop\apps\<app>\current\...`，升级后仍有效，避免硬编码版本号。
- **文档记录最终状态**：每份 README 同时写明「怎么做的」和「现在是什么样」，便于日后排查。
- **记录绝对路径依赖**：凡是写进注册表/任务/配置文件的绝对路径，都要在文档里显式列出（这是最常见的迁移雷）。
- **改完做端到端验证**：不要只看配置项存在，要实际走一遍流程（本项目里有多次「配置对但没生效」的案例）。

## 相关目录

| 内容 | 位置 |
|---|---|
| Everforest 主题管理体系 | `~/Themes/`（git 仓库 `everforest-themes`） |
| GlazeWM / yasb 配置的权威副本 | `~/Projects/my_dot/dotfiles/glazewm/`、`~/Projects/my_dot/dotfiles/yasb/`（由该仓库 `sync-dotfiles.ps1` 部署） |
| pi 插件归档 | `~/.pi/my-plugins/`（git 仓库 `my-plugins`） |
