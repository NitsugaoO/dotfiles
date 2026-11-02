# dotfiles

一套 **Everforest Hard（高对比暗色）** 风格的 Windows 桌面 + 编辑器配置合集：
GlazeWM / yasb / Windhawk / Everything / Edge / VSCode / Neovim / pi / Clash Party。

配色全部来自同一份色板 —— [`palette/tokens.yaml`](palette/tokens.yaml) 里的 **19 个角色**，
没有一处临时调的颜色。

> **本仓库是只读发布镜像。** 配置的权威源在作者的两个私有仓库里（产线 + 备份），
> 这里放的是**渲染完成、可直接使用的成品**。要改配色请改 `palette/tokens.yaml`
> 后按角色重新渲染；想在 issue 里报问题随意，但不建议直接在本仓库提 PR 改配置文件
> （下次导出会覆盖）。

## 目录

| 路径 | 内容 |
|---|---|
| [`palette/`](palette/) | `tokens.yaml` —— 19 个语义角色的唯一色板（SSOT） |
| [`windows/glazewm/`](windows/glazewm/) | GlazeWM 平铺窗口管理器配置 + 启动包装 vbs |
| [`windows/yasb/`](windows/yasb/) | yasb 状态栏：`config.yaml` + 自定义 widget 脚本 + `styles.css` |
| [`windows/windhawk/`](windows/windhawk/) | Windhawk mod 配置：开始菜单 / 任务栏 / 资源管理器 / 玻璃效果 |
| [`windows/everything/`](windows/everything/) | Everything 1.5 暗色主题（粘贴到搜索框即生效） |
| [`windows/tacky-borders/`](windows/tacky-borders/) | tacky-borders 窗口边框配置 |
| [`windows/edge/`](windows/edge/) | Edge 主题扩展（unpacked） |
| [`editors/vscode/`](editors/vscode/) | 见 [`extensions/`](extensions/) —— VSCode 主题以扩展形式提供 |
| [`editors/nvim/`](editors/nvim/) | Neovim 配色 + `init.vim`（Windows / WSL / 远程三端共用） |
| [`editors/pi/`](editors/pi/) | pi（终端 AI 编码器）TUI 主题 |
| [`apps/clash-party/`](apps/clash-party/) | Clash Party 单文件 CSS 主题 |
| [`wsl/`](wsl/) | WSL 小工具：`ida`（WSL 里开 Windows IDA）、`here`、gdb/pwndbg 分屏、tmux |
| [`extensions/everforest-hard/`](extensions/everforest-hard/) | 打包好的 VSCode 扩展（`.vsix`） |
| [`system-tweaks/`](system-tweaks/) | Windows 系统级改动归档：右键菜单、桌面图标开关、GlazeWM 提前自启等 |

## 快速开始

不同应用装法不同，每个目录下的 `README.md` 写了具体步骤。三条最快的：

**VSCode** —— 装打包好的扩展：

```powershell
code --install-extension extensions\everforest-hard\everforest-hard-1.0.0.vsix
```

**yasb 状态栏**（配置 + 配色成对提供）：

```powershell
$dst = "$env:USERPROFILE\.config\yasb"
New-Item -ItemType Directory -Path "$dst\scripts" -Force | Out-Null
Copy-Item windows\yasb\config.yaml, windows\yasb\styles.css $dst -Force
Copy-Item windows\yasb\scripts\* "$dst\scripts" -Force
```

**GlazeWM**：

```powershell
$dst = "$env:USERPROFILE\.glzr\glazewm"
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item windows\glazewm\config.yaml $dst -Force
```

Windhawk / Everything / Edge / pi 的装法见各自目录（有的是粘贴一段配置，有的是 Load unpacked）。

## 关于路径：`%USERPROFILE%` 与 `<YourName>`

仓库里的绝对路径已尽量改成环境变量或占位符，但有三种情况仍然需要你手动确认：

| 写法 | 出现位置 | 为什么要改 |
|---|---|---|
| `C:/Users/<YourName>/scoop/...` | `windows/yasb/config.yaml` 里 obs 组件的 5 行 | yasb 这几行是 `use_shell: false`，**不经过 shell，`~` 和 `%USERPROFILE%` 都不会展开**，只能写绝对路径 |
| `%USERPROFILE%\Projects\dotfiles` | 注册表 `.reg`、nvim 的 junction 命令 | 假定仓库 clone 到这个位置；放别处就要改 |
| `DOMAIN\Username` / `S-1-5-21-...` | `system-tweaks/tweaks/glazewm-startup/GlazeWM-task.xml` | 计划任务定义里的账号占位，导入前换成自己的 |

`.reg` / `.xml` 是 **UTF-16LE** 编码，用编辑器改的时候注意别存成 UTF-8，否则 `reg import` 会报错。

## 配色体系

19 个角色分四组（详见 [`palette/README.md`](palette/README.md)）：

| 组 | 角色 |
|---|---|
| 背景（6） | `最深` `背景` `面板` `浮层` `边框` `加重` |
| 文字（5） | `正文` `次要` `更淡` `最淡` `反色` |
| 状态（5） | `强调` `正常` `注意` `偏高` `危险` |
| 语法（3） | `蓝` `紫` `注释` |

名字对应**用途**而不是色相。想整体调明暗改前 5 个背景角色，想换主题色改中间的「强调 / 正常 / 注意 / 危险」。

## 许可与出处

MIT，见 [LICENSE](LICENSE)。色板与多个配置结构派生自他人的开源项目，
逐项署名见 [THIRD-PARTY.md](THIRD-PARTY.md)。
