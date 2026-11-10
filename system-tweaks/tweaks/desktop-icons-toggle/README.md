# Windhawk Desktop Icons Double-Click Toggle — F2 重命名修复 + 开机自动隐藏

修复 Windhawk Mod **Desktop Icons Double-Click Toggle**（`desktop-icons-double-click-toggle2`，作者 akumy，v1.1）与桌面 F2 重命名冲突的问题。

## 问题描述

安装该 Mod（双击桌面空白处隐藏/显示桌面图标）后，在桌面上选中文件按 **F2 重命名**，编辑框会自己消失（重命名被取消）。

## 根因

Mod 通过 `WH_MOUSE` 钩子监测桌面线程鼠标消息，用 `WindowFromPoint` + `ListView_HitTest` 判断点击是否在"桌面空白处"：

1. 桌面重命名时，`SysListView32` 会创建重命名编辑框（`Edit` 子窗口），其宽度通常大于文件名标签的可点击区域（短文件名时尤其明显）；
2. 在编辑框内点击（如双击选中文字、点两下定位光标）时，超出标签命中区域的点击点使 `ListView_HitTest` 返回 `-1` → 被误判为"桌面空白点击"；
3. 两次点击满足双击条件（时间 ≤ `GetDoubleClickTime()`，距离 ≤ `SM_CXDOUBLECLK`）→ 触发 `ToggleDesktopIconsLocked()` → `ShowWindow` + 强制重绘桌面 → 重命名被取消。

> 注：F2 本身是键盘事件，不经过鼠标钩子；冲突发生在重命名过程中**使用鼠标点击编辑框**时。

## 修复内容（v1.1 → v1.2）

在 `local@desktop-icons-double-click-toggle2.wh.cpp` 中：

1. 新增 `IsDesktopLabelEditingLocked()`：检测 `SysListView32` 是否存在 `Edit` 子窗口（即处于标签编辑/重命名模式）；
2. `IsEligibleDesktopClickPointLocked()` 开头：重命名模式期间直接返回 `false`（不响应任何点击）；
3. `IsEligibleDesktopClickPointLocked()` 中：点击落在 `SysListView32` 子窗口上时（`hwnd != g_listView && IsChild(...)`）排除，不算桌面空白；
4. `ToggleDesktopIconsLocked()` 开头加同样的重命名保护（二次保险）。

双击桌面空白处隐藏/显示图标的功能不受影响。

## v1.3 开机自动隐藏

新增设置项 `HideIconsOnStartup`（默认开启）：mod 加载后等待桌面窗口就绪，自动隐藏一次图标。
Windhawk 服务为开机自启，explorer 启动时注入，因此效果等同于「登录后自动隐藏」；explorer 重启后也会重新隐藏。

实现位置：

- `Settings` 增加 `hideIconsOnStartup`，`LoadSettings()` 读取 `HideIconsOnStartup`；
- `Wh_ModInit()` 设置一次性标志 `g_startupHidePending`；
- `WorkerThreadProc()` 在 `RefreshDesktopWindowsLocked()` 成功后执行一次 `SetDesktopIconsVisibleLocked(false)`，避免桌面未就绪时误操作，也避免用户双击显示后又被反复隐藏。

卸载 mod 时若 `RestoreInitialStateOnUnload=true`，会恢复为加载时的状态（显示）；希望卸载后保持隐藏则关闭该设置。

## 编译修复（v1.2 实际未生效的原因）

v1.2 源码中 `ToggleDesktopIconsLocked()` 调用了后面才定义的 `IsDesktopLabelEditingLocked()`，缺少前向声明，导致编译失败，Windhawk 一直沿用 v1.1 的 DLL。
v1.3 已在 `ToggleDesktopIconsLocked()` 前补上声明：

```cpp
static bool IsDesktopLabelEditingLocked();
```

## v1.3 部署记录（2026-10-23）

使用 Windhawk 自带 clang 手动编译并写入引擎注册表：

- DLL：`C:\ProgramData\Windhawk\Engine\Mods\64\local@desktop-icons-double-click-toggle2_1.3_883825.dll`
- 注册表：`HKLM\SOFTWARE\Windhawk\Engine\Mods\local@desktop-icons-double-click-toggle2`（`Version=1.3`，`Settings\HideIconsOnStartup=1`）
- 源码：`C:\ProgramData\Windhawk\ModsSource\` 与 `EditorWorkspace\mod.wh.cpp`（旧版备份为 `*.v1.2.bak`）
- 注册表备份：`C:\ProgramData\Windhawk\Engine\ModsWritable\backup-desktop-icons-*.reg`

验证：explorer 加载了 `..._1.3_883825.dll`，`SysListView32` 初始 `IsWindowVisible=False`（图标已隐藏）。

> `patch_desktop_toggle_mod.py` 仅适用于 v1.1 → v1.2，不再用于 v1.3，后续以源码为准。

## v1.4：把「重命名保护」下沉到唯一出入口

### 为什么改

v1.3 的保护散落在三处，各自检查 `IsDesktopLabelEditingLocked()`，**唯独 `startup hide`
那一支漏了**：

```cpp
if (g_startupHidePending && RefreshDesktopWindowsLocked()) {
    g_startupHidePending = false;
    if (IsWindowVisible(g_listView))
        SetDesktopIconsVisibleLocked(false);   // 没有重命名保护
}
```

`SetDesktopIconsVisibleLocked()` 内部是 `ShowWindow(g_listView, SW_HIDE)`，父窗口一隐藏，
`SysListView32` 的就地编辑框就会被销毁（实测事件序列 `SHOW -> HIDE -> DESTROY`）。

### 改了什么

1. `SetDesktopIconsVisibleLocked(bool visible, bool protectEditing = true)`：保护下沉到这里，
   startup hide / 双击 toggle / 卸载恢复三条路径共用同一份判断；返回 `bool` 表示是否真的执行；
2. `startup hide` 用返回值决定是否清 `g_startupHidePending` —— 被拦下时**保留 pending**，
   1 秒后重试，避免「开机时正好在重命名」导致自动隐藏永久失效；
3. `Wh_ModUninit()` 的状态恢复传 `protectEditing = false`：卸载时必须尽力还原可见性。

> 这是**防御性修复**，不是根因确认。2026-11-10 那次「F2 编辑框闪现即消失」的根因仍未确定，
> 见下方「诊断记录」。

## 编译命令（复刻 Windhawk 自己的参数）

Windhawk UI 的编译逻辑藏在
`C:\Program Files\Windhawk\UI\resources\app\extensions\windhawk\dist\extension.js`（`compileModInternal`）。
提炼出来就是：

```powershell
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' `
  -std=c++23 -O2 -shared -DUNICODE -D_UNICODE `
  -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00 -D_WIN32_IE=0x0A00 -DNTDDI_VERSION=0x0A000008 `
  -D__USE_MINGW_ANSI_STDIO=0 -DWH_MOD `
  '-DWH_MOD_ID=L"desktop-icons-double-click-toggle2"' '-DWH_MOD_VERSION=L"1.4"' `
  'C:\Program Files\Windhawk\Engine\1.7.3\64\windhawk.lib' `
  -x c++ '<源码路径>' -include windhawk_api.h -target x86_64-w64-mingw32 `
  -Wl,--export-all-symbols -o '<输出.dll>' -lcomctl32
```

要点：

- 链接的是 **`windhawk.lib`**（随 Engine 版本变化），不是 `windhawk-mod-shim.dll`；
- `-include windhawk_api.h` 需要 `Compiler\include` 可被找到（在 `Compiler` 目录下运行最稳）；
- 自检方法：v1.3 源码按此参数编译出来是 **72704 字节**，与线上
  `local@desktop-icons-double-click-toggle2_1.3_883825.dll` 一致。

## 诊断记录（2026-11-10）：F2 编辑框闪现即消失

**现象**：桌面选中文件按 F2，编辑框出现后约 30–50ms 自己消失，改名被取消。

**取证手段**（只读，脚本留在 `C:\Users\<YourName>\Projects\scratch\`）：
`f2-probe.ps1`（子树 + 焦点）、`f2-probe2.ps1`（全顶层窗口 + DefView 全子孙，15ms 一帧）、
`f2-focuslog.ps1`（`SetWinEventHook` 记录 CREATE/SHOW/HIDE/DESTROY/FOCUS/FOREGROUND 及所属进程）。

**结论**：

| 观察 | 数据 |
|---|---|
| 编辑框位置 | `Edit` 是 `SysListView32` 的**直子窗口**（`parent=SysListView32`），所以 v1.3 的 `FindWindowExW(g_listView, nullptr, L"Edit", nullptr)` 本身是有效的 |
| 生命周期 | `CREATE(9697) → SHOW(9713) → HIDE(9730) → DESTROY(9730)`，约 33ms |
| 凶手 | 这 33ms 内 WinEventHook **没有收到任何** `FOREGROUND`/`FOCUS` 事件 → 不是外部抢焦点，是 explorer 自己结束就地编辑 |
| 是否 mod 的 toggle | 全程 `lv=vis`，`ShowWindow`/`RedrawWindow` 未执行 |
| 排除项 | `close-explorer-on-esc` 只认 `CabinetWClass`/`ExploreWClass` 且只吃 `VK_ESCAPE`，够不到桌面 `Progman` |

**未解**：关闭并重新启用该 mod 后现象消失 → 更像某个**运行期状态**（鼠标钩子 / worker 线程 /
内部缓存）坏掉后被 `Wh_ModUninit` + `Wh_ModInit` 重置。属于「重启治百病」，根因未确认。

**复发时怎么抓**：先跑 `f2-focuslog.ps1 -Seconds 240 -Out <路径>`，再按 F2，然后看时间线里
`Edit` 存活多久、期间有没有别的进程事件。

## 部署脚本（v1.4）

`deploy-v1.4.bat`（双击，自动请求 UAC）→ 调用 `deploy-v1.4.ps1`：

1. 备份注册表键到 `Engine\ModsWritable\backup-<id>-<时间>.reg`，旧 DLL 备份为 `*.bak`；
2. 用上面的 clang 参数编译，DLL 落到 `Engine\Mods\64\local@desktop-icons-double-click-toggle2_1.4_<seq>.dll`；
3. 源码同步到 `ModsSource\` 与 `EditorWorkspace\`；
4. 写注册表 `LibraryFileName` / `Version`（Windhawk 靠这两个字段找 DLL）；
5. 加 `-RestartService` 可重启 Windhawk 服务；不加则需在 Windhawk UI 里把该 mod 关开一次。

> 部署脚本必须 **UTF-8 with BOM**（同 `sync-dotfiles.ps1`，PS 5.1 否则按 GBK 解析中文报语法错）。

## 文件清单

| 文件 | 说明 |
|---|---|
| `desktop-icons-double-click-toggle2.wh.cpp` | 修复后源码（v1.4，重命名保护下沉 + 开机自动隐藏 + F2 修复） |
| `desktop-icons-double-click-toggle2-original-v1.1.wh.cpp` | 原始源码（v1.1），未修改 |
| `patch_desktop_toggle_mod.py` | 自动打补丁脚本（原文件 → 修复版，含全部 4 处替换），仅 v1.1→v1.2 适用 |
| `deploy-v1.4.ps1` / `deploy-v1.4.bat` | v1.4 编译 + 部署脚本（管理员；bat 自动请求 UAC） |
| `README.md` | 本文档 |

## 已修改的系统文件

- `C:\ProgramData\Windhawk\ModsSource\local@desktop-icons-double-click-toggle2.wh.cpp`（实际加载的源码）
- `C:\ProgramData\Windhawk\EditorWorkspace\mod.wh.cpp`（Windhawk UI 编辑器工作区副本）
- 备份：`local@desktop-icons-double-click-toggle2.wh.cpp.bak` / `mod.wh.cpp.bak`（v1.1 原版）

## 重新应用修复

```bat
copy /y "desktop-icons-double-click-toggle2.wh.cpp" "C:\ProgramData\Windhawk\ModsSource\local@desktop-icons-double-click-toggle2.wh.cpp"
copy /y "desktop-icons-double-click-toggle2.wh.cpp" "C:\ProgramData\Windhawk\EditorWorkspace\mod.wh.cpp"
```

（需要管理员权限，之后在 Windhawk UI 中关闭再启用该 Mod 触发重新编译）

## 回滚

```bat
copy /y "C:\ProgramData\Windhawk\ModsSource\local@desktop-icons-double-click-toggle2.wh.cpp.bak" "C:\ProgramData\Windhawk\ModsSource\local@desktop-icons-double-click-toggle2.wh.cpp"
copy /y "C:\ProgramData\Windhawk\EditorWorkspace\mod.wh.cpp.bak" "C:\ProgramData\Windhawk\EditorWorkspace\mod.wh.cpp"
```

（需要管理员权限，之后重新启用 Mod）

## 验证

- 登录或重启 explorer 后，桌面图标自动隐藏
- 双击桌面空白处 → 图标正常显示；再次双击 → 隐藏
- 选中桌面文件 → F2 → 在编辑框内双击/点击 → 重命名不再被取消
- 重命名进行中时，**开机自动隐藏 / 双击切换**都不应该把编辑框弄没（v1.4）
- 重启 explorer 后再次自动隐藏（mod 只执行一次启动隐藏，不会在双击显示后反复隐藏）

归档日期：2026-09-05（v1.3 更新：2026-10-23；v1.4 更新：2026-11-10）
