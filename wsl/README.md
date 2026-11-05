# wsl

给 WSL（`Ubuntu-24.04`）用的小命令。**权威源在这里**，部署到 WSL 内的 `~/.local/bin/`。

| 文件 | 作用 |
| --- | --- |
| [`bin/ida`](./bin/ida) | 在 WSL 终端里用 **Windows 版 IDA** 打开文件 |
| [`bin/here`](./bin/here) | 在 **Windows 资源管理器**里打开 WSL 的当前目录 |
| [`gdb/`](./gdb) | pwndbg context 分屏：把栈/寄存器/反汇编输出分流到侧边 pane |
| [`tmux/`](./tmux) | tmux 配置（dojo 与 WSL 共用同一份） |

## 部署

```powershell
cd %USERPROFILE%\Projects\dotfiles
.\sync-dotfiles.ps1            # 部署（-WhatIf 可预演）
```

WSL 那段用 `wsl.exe -- install -m 755 -D <源> <目标>`，而不是 `Copy-Item` 直接写
`\\wsl.localhost\...` —— 后者会把**可执行位丢掉**，写过去是个 644 的脚本，`ida: command not found` 或
`Permission denied`。用 `install` 一次到位。

- 发行版名写死在脚本顶部的 `$wslDistro`；家目录由 `wsl.exe -- sh -c 'echo $HOME'` 自动探测，换用户名不用改
- 源路径用 `ConvertTo-WslPath` 从 `C:\...` 换算成 `/mnt/c/...`
- 改完不需要热重载，新开一个 shell（或 `hash -r`）即可

⚠ `gdb/gdbinit` 会**整体覆盖** `~/.gdbinit`（它是权威源）。它只做三件事：source pwndbg、
关掉 debuginfod、source 分屏脚本。有自己的 gdb 配置请写进 `gdb/gdbinit` 一起入库。

## gdb / pwndbg 分屏

把 pwndbg 的 context 拆成 5 块：左边主 pane 跑程序和 gdb 命令，右边一列 4 个 pane 从上到下是
`BACKTRACE / STACK / REGS / DISASM`。这样 pwndbg 的输出就不会和程序自己的输出糊在一起。

| 文件 | 生效位置 |
| --- | --- |
| [`gdb/gdbinit`](./gdb/gdbinit) | `~/.gdbinit` |
| [`gdb/pwndbg-ctx-split.gdb`](./gdb/pwndbg-ctx-split.gdb) | `~/.gdbinit.d/pwndbg-ctx-split.gdb` |
| [`gdb/pane.sh`](./gdb/pane.sh) | `~/.gdb-ctx/pane.sh` |

**用法（tmux，推荐）**：在 Windows Terminal 里跑 `tmux`，然后照常 `gdb ./pwn` —— 启动时自动分屏，
退出 gdb 时自动收起。gdb 内可用命令：

| 命令 | 作用 |
| --- | --- |
| `ctx-split` | 手动分屏 |
| `ctx-attach` | 接上各 pane 里 `pane.sh` 登记过的 tty |
| `ctx-kill` | 清理分屏出来的 tmux pane |

环境变量 `PWNDBG_NO_CTX_SPLIT=1` 可禁用自动分屏（用 `pwn.gdb.debug` 时建议加上）。

### 为什么 Windows Terminal 原生 pane 默认不自动开

WT 的 `wt.exe -w <窗口>` 得先能确定"当前窗口"。从 WSL 里调用时，WSL interop 起的 `wt.exe`
**没有控制台归属**，`-w 0` / `-w last` / `-w {GUID}` 全都定位不到，结果是**每调一次就新开一个窗口**
（实测四个 pane 的 `WT_SESSION` 各不相同），所以默认不这么做。

想要 WT 原生 pane（可以用鼠标拖拽大小、每个 pane 独立滚动）有两条路：

1. **手动分屏 + `ctx-attach`**：在目标窗口里手动分出 4 个 pane，每个跑
   `~/.gdb-ctx/pane.sh <section>`（section 取 `backtrace/stack/regs/disasm`），再在 gdb 里
   `ctx-attach`。它们把 tty 记在 `~/.gdb-ctx/<section>`，gdb 下次启动会自动认领（6 小时内的登记）。
2. **窗口名**：给 WT profile 配上 `"windowName": "pwn"`，用该 profile 开窗口，然后
   `export PWNDBG_CTX_WT_WINDOW=pwn`，`ctx-split` 就能把 pane 分进那个窗口。

## tmux

[`tmux/tmux.conf`](./tmux/tmux.conf) → `~/.tmux.conf`：与 dojo 侧**共用同一份内容**
（dojo 的源在 `my_pwn/env/tmux.conf`），改任一处都要同步另一处。

| 配置 | 作用 |
| --- | --- |
| `mouse on` | WT 里滚轮翻历史（自动进 copy-mode）、点选 pane、拖边框改大小 |
| `escape-time 10` | vim 里 Esc 不再卡 500ms |
| `history-limit 50000` | 默认 2000 行，gdb / disasm 一刷就没 |
| `base-index 1` / `pane-base-index 1` | 窗口 / 窗格从 1 编号 |
| `bind \|` / `bind -` | 左右 / 上下分屏，新 pane 继承当前目录（需 tmux >= 3.0） |
| `set-clipboard on` | OSC52 写系统剪贴板（WT 支持；不生效就注释掉） |

⚠️ `base-index` / `pane-base-index` 只影响**新建的 session**，已存在的 session 里旧编号不追溯。

## ida

```bash
ida <file>          # 直接打开（WSL 内的文件走 \\wsl.localhost）
ida --copy <file>   # 先复制到 Windows 临时目录再打开（IDA 读写全在本地盘，最快）
ida                 # 只启动 IDA
ida --help
```

- IDA 位置自动探测 `C:\Program Files\IDA*\ida.exe`，取版本号最大的那个，**升级 IDA 不用改脚本**；
  可用 `IDA_EXE` 覆盖
- 打开 `/mnt/c/...` 下的文件不会走 UNC —— 它本来就在 Windows 盘上，直接换算成 `C:\...`

### 坑 1：不能用 `cmd.exe /c start` 启动

WSL2 ↔ ConPTY interop 的已知 bug：`cmd /c start <GUI程序>` **不会真的 fork**，子进程继续占着终端的
控制台句柄，提示符回不来、`Ctrl+C` 也常常按不动 —— 见
[microsoft/WSL#5811](https://github.com/microsoft/WSL/issues/5811)（相关修复
[#16340](https://github.com/microsoft/terminal/pull/16340)、
[#16445](https://github.com/microsoft/terminal/commit/17867af5349a66fa8121d1c930dd9587e45f5117)）。

现在默认走 PowerShell 的 `Start-Process`（ShellExecute，子进程不继承 interop 的 std 句柄）：

```bash
ida <file>                        # 默认：powershell Start-Process
IDA_LAUNCHER=setsid ida <file>    # 备选：setsid + 丢弃全部 stdio + 后台
```

如果哪天又卡住：先试 `IDA_LAUNCHER=setsid`；两种都卡就 `wsl --shutdown`
（⚠️ 会杀掉 WSL 里所有进程）—— 卡死的 interop socket 状态是**粘滞**的，重启 WSL 才清得掉。

### 坑 2：`wslpath -w` 对相对路径会原样返回

`wslpath -w README.md` 会直接吐回 `README.md`（不存在或非绝对路径时不转换），所以脚本里
**先 `realpath` 再转换**。转换结果正好是我们要的两种形式：WSL 内文件 → `\\wsl.localhost\...`，
`/mnt/c` 下的文件 → `C:\...`。

### --copy 的取舍

默认直接按 `\\wsl.localhost\...` 打开：零拷贝、不改动样本。代价是 IDA 会在样本同目录写 `.i64`，
且随机读走 9p 偏慢。

大样本（或想让数据库落在本地盘）用 `--copy`：落地到 `%LOCALAPPDATA%\Temp\ida-wsl\`，
可用 `IDA_COPY_DIR` 改。

## here

```bash
here                # 在资源管理器里打开当前目录
here ~/ctf          # 打开指定目录
here ./chall        # 打开所在目录并选中该文件
here -n             # 强制开新窗口
```

用的是 `explorer.exe` —— 它只把请求转交给已在运行的 explorer 进程、自己立刻退出，
所以**不会**遇到 `ida` 那种 interop 占终端的问题（成功时它也返回 1，退出码不能当错误判断）。

- 目录 → `explorer.exe <Win路径>`（不带 `-n` 时按系统“在同一窗口打开”的设置）
- 文件 → `explorer.exe /select,<Win路径>`（打开所在目录并高亮该文件）
- 路径换算同上：由 `wslpath` 处理，WSL 内 → `\\wsl.localhost\...`，`/mnt/c` 下 → `C:\...`

资源管理器窗口会被 GlazeWM 自动浮动 —— 靠 `glazewm/config.yaml` 里 `explorer` + `CabinetWClass` 那条规则。

## 故障排除

### `/mnt/c`、`/mnt/d` 挂载失效（Input/output error）

**症状**：`ls /mnt/c` 报 `Input/output error`；`mount` 仍然显示挂载着（9p/drvfs）；
从 Windows 侧启动 wsl 时报 `WSL (xxxx - Relay) ERROR: CreateProcessCommon:810: chdir(...) failed 5`；
`ida` 莫名报“没找到 ida.exe”（其实 `find_ida` 里 `ls` 拿到的是空 stdout）。

**成因**：DrvFs/9p 通道断掉。已知诱因是**在 /mnt/c 上做 I/O 时进程被 Ctrl+C / 被杀**
（[microsoft/WSL#4377](https://github.com/microsoft/WSL/issues/4377)）。

**修复（不用重启 WSL）**：

```bash
wsl.exe -d Ubuntu-24.04 -u root -- bash -c 'umount -l /mnt/c && mount -t drvfs C: /mnt/c'
# D 盘同理（C: 坏时 D: 通常一起坏）：
#   ... bash -c 'mount -t drvfs D: /mnt/d'
```

> ⚠️ 在 **Git Bash** 里敲这条要小心：`/mnt/c` 会被 MSYS 的路径转换改写成
> `C:/Program Files/Git/mnt/c`，umount/mount 就变成了空打（报 “no mount point specified”）。
> 务必像上面那样把路径包在 `bash -c '...'` 里交给 WSL 自己解析，或加 `MSYS_NO_PATHCONV=1`。

**兜底**：`wsl --shutdown` 后重进（⚠️ 会杀掉 WSL 内所有进程，tmux/后台任务一起没）。

**预防**：`ida` / `here` 里的 `timeout 30` 只是兜底，别在它跑的时候按 Ctrl+C。
