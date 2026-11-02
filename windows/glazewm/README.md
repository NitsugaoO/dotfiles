# GlazeWM 配置

GlazeWM 平铺窗口管理器的**权威配置**：工作区、快捷键、window_rules、全屏行为。

> 配色（窗口边框 `#a7c080`、非聚焦 `#414b50`）是**硬编码**在这个文件里的，
> 不由 `everforest-themes` 的 tokens 生成 —— 因为 GlazeWM 的配置能力有限，
> 没法像 CSS 那样注入变量。

## 部署

GlazeWM **没有 `--config` 参数**（配置路径硬编码在 `~\.glzr\glazewm\`），所以必须拷贝：

```powershell
cd %USERPROFILE%\Projects\dotfiles
.\sync-dotfiles.ps1
```

拷完按 `Alt+Shift+R` 热重载。

## 关键设置与原因

| 设置 | 值 | 原因 |
| --- | --- | --- |
| `window_behavior.state_defaults.fullscreen.maximized` | `true` | 让 `Alt+F` 走 **Windows 原生最大化**路径，会自动避开 yasb 注册的 AppBar（顶部 34px）；设成 `false` 时 GlazeWM 用自研全屏实现，会覆盖到显示器物理边缘，把状态栏一起吃掉 |
| `window_rules` 中的 `ignore` | 见配置 | 让 QQ / Clash Party / SakuraLauncher 等完全不受 WM 管理 |
| `window_rules` 中的 `set-floating` | 见配置 | 让 wsrx-desktop、文件资源管理器（限 `CabinetWClass`／`ExploreWClass`，避免连桌面与任务栏一起命中）、NanaZip（`^NanaZip`）自动浮动 |
| IDA 的 `set-floating` 用 `window_title: not_regex` | `'^IDA\b'` | IDA 的弹窗与主窗口**进程名、窗口类名完全相同**（实测 IDA Free 9.4：都是 `ida` / `Qt682QTQWindowIcon`，且弹窗 owner 为 NULL、同样可调大小），GlazeWM 又只有 `window_process`/`window_class`/`window_title` 三个匹配维度，没有「这是不是对话框」的判定 —— 所以只能把**主窗口**用标题摘出去：主窗口标题永远是 `IDA` 开头（`IDA - <文件> - Only for non-commercial use` / 未开文件时 `IDA: Quick start`），弹窗是 `Load a new file`、`Add breakpoint`… 之类。想改成「IDA 整体浮动」就把 `window_title` 那行删掉 |
| `window_effect` / `gaps` | Everforest 色 | 纯视觉，与 `everforest-themes` 里的色板人工对齐 |

## 已知小毛病

- `maximized: true` 时，从全屏切回平铺偶发 gaps 失效
  （[issue #1277](https://github.com/glzr-io/glazewm/issues/1277)），
  切一下 workspace、或再按一次 `Alt+F` 即可恢复。
- GlazeWM 报的窗口尺寸对 OS 最大化状态并不完全准（账面 `monitor bounds` vs Windows 实际
  摆在 work area 内），排查时别只看 `glazewm query windows` 的数字。

## 启动

`launch-glazewm.vbs`（无控制台窗口启动）+ 计划任务。相关归档原先在
`system-tweaks/tweaks/glazewm-startup/`，现在配置本体已迁到本目录。
