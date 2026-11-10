# 右键「新建」菜单自定义（加 md/c/cpp/py，去 BMP）

> 在资源管理器 / 桌面的「新建」子菜单里加入 **Markdown 源文件 / C 源文件 / C++ 源文件 / Python 文件**，
> 并去掉 **BMP 图像**（以及可选的 Excel / PowerPoint）。

## 来源

- 归档日期：2026-11-07
- 环境：Windows 11 26100.9949（24H2）
- 实现：`HKCU\Software\Classes`（加项，无需管理员）+ `HKLM\Software\Classes`（去 Office 项，需管理员）
  + `HKCU\...\MrtCache`（去 BMP，无需管理员）

## 最终效果

```
新建(N)
├─ 文件夹
├─ 快捷方式
├─ C 源文件              ← 新增
├─ C++ 源文件            ← 新增
├─ Microsoft Word 文档    （保留）
├─ Markdown 源文件       ← 新增
├─ Python 文件           ← 新增
└─ 文本文档
（BMP 图像 / PowerPoint / Excel 已移除）
```

## 文件说明

| 文件 | 说明 |
|---|---|
| `add-new-file-items.ps1` | **一键应用**：加 4 个空文件项 + 移除“BMP 图像”。幂等，可重复跑。用 `pwsh` 执行 |
| `remove-new-file-items.ps1` | 撤销上面全部改动（含把“BMP 图像”恢复回去） |
| `remove-office-new-items.ps1` | 移除 Excel / PowerPoint 新建项。**需管理员**（动 HKLM） |
| `dump-new-menu.ps1` | **诊断工具**：不开界面直接读出「新建」子菜单的真实内容（含项 ID） |
| `backup-office-shellnew/*.reg` | 删除前导出的 Excel / PowerPoint `ShellNew` 原键，导入即恢复（需管理员） |

> 所有 `.ps1` 均为 **UTF-8 with BOM**（PowerShell 5.1 会把无 BOM 的 UTF-8 按 GBK 解析，中文注释直接语法错误）。

## 机制（这是本项目最关键的部分）

Win11 的「新建」菜单由**三部分**拼成，缺一个都不显示：

### ① 菜单项缓存列表

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Discardable\PostSetup\ShellNew
    Classes   REG_MULTI_SZ
```

系统自动维护，加完 ShellNew 后 `.md/.c/.cpp/.py` 会自动出现在里面（当前值：
`.c .cpp .docx .library-ms .lnk .md .py Folder`）。它只是缓存，**删这里不会去掉 UWP 来源的项**。

### ② 文件类型：`ShellNew` 必须在**扩展名键这一层**

```
HKCU\Software\Classes\.md\ShellNew     ← 有效
HKCU\Software\Classes\.c\ShellNew      ← 有效
HKCU\Software\Classes\.cpp\ShellNew    ← 有效
HKCU\Software\Classes\.py\ShellNew     ← 有效（沿用已有 Python.File）
        NullFile = ""（REG_SZ，空字符串 → 创建 0 字节文件）
```

**两个硬条件**：

1. **必须挂在 `HKCR\.<ext>\` 之下**。挂在 `HKCR\<ProgID>\ShellNew`（扩展名键**外面**）不生效；
   挂在 `.<ext>\<ProgID>\ShellNew`（Office 那种嵌套写法）有效。
2. **该扩展名必须有可用的默认 ProgID**——即 `HKCR\.<ext>` 的默认值指向一个关联了真实程序的类型
   （有 `shell\open\command`）。没有 ProgID 的扩展名，`ShellNew` 会被**静默忽略**。
   这就是 `.md/.c/.cpp` 最初不出现的原因。

所以本项目把 `.md/.c/.cpp` 关联到 **VS Code 安装时注册好的 ProgID**：

| 扩展名 | 默认 ProgID | 显示名（来自 ProgID 默认值） |
|---|---|---|
| `.md` | `VSCode.md` | Markdown 源文件 |
| `.c` | `VSCode.c` | C 源文件 |
| `.cpp` | `VSCode.cpp` | C++ 源文件 |
| `.py` | `Python.File`（原有） | Python 文件 |

> ⚠️ **副作用**：双击 `.md/.c/.cpp` 会**直接用 VS Code 打开**（原先默认值为空 = 弹“选择打开方式”）。
> 这是 Win11 的硬性前提，不关联就不会显示新建项。想换编辑器走「设置 → 默认应用」。

### ③ UWP 应用贡献的项（BMP / 文本文档）

「BMP 图像」「文本文档」**不在 `HKCR` 里**，注册表里也搜不到这两个字符串——
它们来自**画图 / 记事本两个 Store 应用**的资源名，解析后的值缓存在：

```
HKCU\Software\Classes\Local Settings\MrtCache\C:%5CProgram Files%5CWindowsApps%
   5CMicrosoft.Paint_<版本>...\microsoft.system.package.metadata\<SID>-MergedResources-<n>.pri\
   <hash>\<hash>
      值名形如：@{Microsoft.Paint_11.x? ms-resource://Microsoft.Paint/Resources/ShellNewDisplayName_Bmp}
      值数据：  BMP 图像
```

把该**值数据清空** → 菜单项消失。同理 `ShellNewDisplayName_Txt` 控制「文本文档」。

> 该键路径**超过 260 字符**，`OpenSubKey(完整路径)` 会返回 `null`，必须**逐级打开**。

## 注册表改动一览

| 位置 | 改动 | 权限 |
|---|---|---|
| `HKCU\Software\Classes\.md` 的 `(默认)` | `VSCode.md` | 用户 |
| `HKCU\Software\Classes\.md\ShellNew` | `NullFile` = `""` | 用户 |
| `HKCU\Software\Classes\.c` / `.cpp` | 同上（`VSCode.c` / `VSCode.cpp`） | 用户 |
| `HKCU\Software\Classes\.py\ShellNew` | `NullFile` = `""` | 用户 |
| `HKCU\...\MrtCache\...Paint...` 的 `ShellNewDisplayName_Bmp` | 值清空 | 用户 |
| `HKLM\SOFTWARE\Classes\.xlsx\Excel.Sheet.12\ShellNew` | **删除** | 管理员 |
| `HKLM\SOFTWARE\Classes\.pptx\PowerPoint.Show.12\ShellNew` | **删除** | 管理员 |

> 只删 `ShellNew` 子键，**不影响**双击打开 `.xlsx/.pptx`（ProgID、`shell\open\command`、模板文件都保留）。
> `HKCU\Software\Classes\VSCode.md\ShellNew` 这种外层写法**无效**，已在本项目中试过并删除。

## 安装 / 重建

```powershell
cd %USERPROFILE%\Projects\dotfiles\system-tweaks\context-menu\new-file-items
pwsh -File .\add-new-file-items.ps1            # 加 4 项 + 去 BMP

# 去 Excel / PowerPoint（会弹 UAC，或直接用管理员 PowerShell 跑）
powershell -Command "Start-Process pwsh -Verb RunAs -Wait -ArgumentList '-NoProfile','-File','.\remove-office-new-items.ps1'"
```

## 验证

不开界面直接读菜单（推荐，改完立刻可验，无需重启 explorer）：

```powershell
powershell -NoProfile -STA -File .\dump-new-menu.ps1
# 结果写在 %TEMP%\newmenu-dump.txt，看「新建(&W) >」那一段
```

> 原理：`SHGetDesktopFolder` → `IShellView::GetItemObject(SVGIO_BACKGROUND)` → `IContextMenu::QueryContextMenu`，
> 再对每个子菜单调 `IContextMenu3::HandleMenuMsg2(WM_INITMENUPOPUP, <子菜单句柄>, <项位置>)`。
> **`wParam` 必须是“正在初始化的子菜单句柄”**（传顶层菜单句柄会返回 `E_FAIL`，子菜单是空的）。
> `IShellView` 接口声明必须先写 `IOleWindow` 的两个方法，否则 vtable 错位、`GetItemObject` 返回 `E_NOTIMPL`。

## 卸载

```powershell
pwsh -File .\remove-new-file-items.ps1          # 撤销 4 项 + 恢复“BMP 图像”
# 恢复 Excel / PowerPoint：右键导入 backup-office-shellnew\*.reg（需管理员）
```

## 踩坑速查

| 症状 | 原因 |
|---|---|
| 加了 `ShellNew` 但菜单没反应 | ① 挂错层（应是 `HKCR\.<ext>\ShellNew`）；② 扩展名没有可用 ProgID |
| `HKCR\<ProgID>\ShellNew` 无效 | 扩展名键**外面**的 ProgID 不被扫描，必须挂在 `.<ext>\` 之内 |
| 注册表里根本没有 `.bmp\ShellNew`，却一直有「BMP 图像」 | 来自 Store 应用资源（MrtCache），不在 `HKCR` |
| 改 MrtCache 报 `null` | 键路径 > 260 字符，要**逐级** `OpenSubKey` |
| `reg.exe query` 报“无效项名” | 从 Git Bash 传参时反斜杠被 MSYS 转换；用 `MSYS2_ARG_CONV_EXCL='*'` 或改走 .NET API |
| 32 位视图误导 | 32 位进程读 `HKCR` 得到的是 Wow6432Node 合并视图，`.txt/.bmp` 会“看起来不存在” |
| Excel/PPT 新建项又回来了 | Office 更新/联机修复会重建 `ShellNew`，重跑 `remove-office-new-items.ps1` |
| BMP 图像又回来了 | MrtCache 是缓存，可能被系统重建，重跑 `add-new-file-items.ps1` |

> 💡 判断某个扩展名为什么不出现在菜单里：先 `reg query HKCR\.<ext>` 看有没有**默认 ProgID**，
> 再看该 ProgID 有没有 `shell\open\command` 指向真实存在的 exe。
