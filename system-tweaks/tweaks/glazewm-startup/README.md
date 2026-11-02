# GlazeWM 提前自启（yasb 不再最后启动）

> 把 GlazeWM 从 `HKCU` Run 键挪到**登录触发的计划任务**，绕开 explorer 的启动队列，
> 让 GlazeWM（及其拉起的 yasb 状态栏）尽早启动。
>
> ⚠️ **2026-09-24 起触发器带 `Delay=PT15S`** —— 「尽早」必须有下限。`Delay=0` 会把
> GlazeWM 扔进登录初期「shell/COM 尚未就绪」的竞态窗口，导致**每次开机必崩**
> （原因、实测数据与修复过程见「坑 4」）。

## 来源

- 处理日期：2026-09-13
- **更新 2026-09-24**：修复 `Delay=0` 引发的开机崩溃，触发器改为 `Delay=PT15S`（见坑 4）
- 起因：用户反馈「每次开机 yasb 都是最后启动」
- 会话产物：`launch-glazewm.vbs`、计划任务 `GlazeWM`、Run 键备份

## 问题定位

原启动方式是 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 里的 `GlazeWM` 项，
排在 12 个 Run 项中**倒数第二**。而 yasb 并不自启，是由 GlazeWM 拉起的：

```yaml
# ~/.glzr/glazewm/config.yaml
general:
  startup_commands: ['shell-exec yasb']
```

所以链路是：**explorer 处理 Run 队列 → GlazeWM 启动 → 初始化完成 → 执行 shell-exec → yasb**。
GlazeWM 本身就排在队尾，初始化又要时间，yasb 自然是最后一个出现。

## 关键概念：Run 键顺序 ≠ 实际启动顺序

- Run 键的值按 **ASCII 升序发起**，但各进程**异步并行**加载，谁先初始化完谁先出现。
- 真正能精确控制的是**计划任务 + 延迟**。
- 计划任务由 **Task Scheduler 服务**在登录事件发生时直接触发，**不依赖 explorer**，
  因此比 Run 项更早。

## 最终配置

### 计划任务 `GlazeWM`

| 项 | 值 |
|---|---|
| 触发器 | 登录时（`DOMAIN\Username`），**延迟 15 秒**（`<Delay>PT15S</Delay>`，2026-09-24 起，见坑 4） |
| 运行身份 | `Interactive` / `Limited`（**非提权**，与原 Run 键行为一致） |
| 动作 | `C:\Windows\System32\wscript.exe` |
| 参数 | `//B "%USERPROFILE%\.glzr\launch-glazewm.vbs"` |
| 时长限制 | `PT0S`（不限时，防止默认 72 小时被强杀） |
| 电源 | 允许电池时启动 |
| 状态 | Ready |

> ⚠️ **`RunLevel` 必须保持 `Limited`**。改为 `Highest` 需要管理员权限（会报"拒绝访问"），
> 而且会让 GlazeWM 以高完整性运行，改变原有行为——本方案**不需要**提权。

### 启动包装脚本

`~/.glzr/launch-glazewm.vbs`（副本见本目录）：

```vbs
Set sh = CreateObject("WScript.Shell")
sh.Run """C:\Users\<YourName>\scoop\apps\glazewm\current\glazewm.exe""", 0, False
```

用 `wscript.exe` 而非 `cmd.exe` 执行，是因为 **wscript 是 GUI 子系统程序，不创建控制台窗口**，
登录时**不会闪黑框**。`Run` 的 `0` = 隐藏窗口，`False` = 不等待。

### 完整启动链

```
Task Scheduler ──> wscript.exe ──> launch-glazewm.vbs ──> glazewm.exe ──> yasb (父)
                        (GUI,无窗)     (Run...,0 隐藏)                        └─> yasb (子)
```

> ℹ️ yasb 常驻 **两个进程**（父子关系），这是它的**正常架构**，不是重复实例。
> 排查时不要误判为多开。

## ⚠️ 踩坑记录（核心）

### 坑 1：计划任务直接启动 glazewm.exe 失败，错误码 740

**现象**：任务确实触发了（`LastRunTime` 正常更新），但 GlazeWM 没起来，任务返回
`2147943140`。

**错误码换算**（这是排错的关键技能）：

```
2147943140 = 0x800702E4
  → HRESULT 框架：0x8007 = FACILITY_WIN32，低 16 位 0x02E4 = 740
  → Win32 error 740 = ERROR_ELEVATION_REQUIRED（需要提升权限）
```

**根因**：`glazewm.exe` 的 manifest 带 UIAccess 标记：

```
requestedExecutionLevel level="asInvoker" uiAccess="true" />
```

`uiAccess="true"` 是给「需要操作高权限窗口的辅助功能程序」用的。计划任务以
`LeastPrivilege` 令牌**直接** `CreateProcess` 该 exe 时，Windows 的 UIAccess 安全检查会拒绝。

**诊断实验**（可复用的排错思路）：

| 实验 | 结果 | 推论 |
|---|---|---|
| 同配置任务启动 `notepad.exe` | ✅ 成功 | 任务配置本身没问题 |
| 同配置任务启动 `glazewm.exe` | ❌ 740 | 问题特定于这个 exe |
| 通过 `cmd.exe` / `wscript.exe` 中转启动 | ✅ 成功 | **绕过方案确认** |

**为什么中转有效**：实际的 `CreateProcess` 发生在中转程序（普通用户态进程）内部，
不再走 Task Scheduler 直接启动时的那条检查路径。

> 🔍 **一个未完全解释清的细节**：从普通 shell（非提权）**直接**运行 `glazewm.exe` 是**成功**的，
> 只有计划任务的 `LeastPrivilege` 令牌会撞上这个检查。UIAccess 在 Windows 内部的判定条件
> 没有完整公开文档，所以这里采取的是**不纠结机制、用实验确定可行方案**。
> 如需深究，可用 Process Monitor 对比两条路径的 `CreateProcess` 结果。

### 坑 2：改 `RunLevel=Highest` 需要管理员权限

尝试用 `Set-ScheduledTask -Principal (New-ScheduledTaskPrincipal -RunLevel Highest ...)`
会直接报「拒绝访问」。**本方案不需要提权**，遇到这个提示不必去开管理员终端。

### 坑 3：诊断过程中会产生重复实例

测试期间我启动过多个 GlazeWM 实例。所幸 GlazeWM **有单实例保护**（后启动的会自行退出），
但**副作用是 yasb 会变成孤儿进程**（父 GlazeWM 已死，旧 yasb 仍在跑，且不会自动重连新实例）。

**处理**：杀掉全部 yasb，再由 GlazeWM 重新拉起，或重启。

### 坑 4：`Delay=0` 导致每次开机 GlazeWM 必崩（2026-09-24 发现并修复）

**现象**：用户反馈「有时候开机不会自动拉起 GlazeWM」。但排查后发现**任务每次都正常
触发了，只是 GlazeWM 启动后 3~4 秒就崩溃**——不是「没拉起」，是「拉起后立刻死了」。

**崩溃签名**（`Get-WinEvent` → Application / Event ID 1000）：

```
出错应用程序名称： glazewm.exe
出错模块名称：     ucrtbase.dll
异常代码：         0xc0000409        （异常数据 = 7）
错误偏移：         0x00000000000a527e
```

- `0xc0000409` + 数据 `7` = `__fastfail(FAST_FAIL_FATAL_APP_EXIT)`，即 `abort()`。
  GlazeWM 是 Rust 写的，panic 走 abort 就是这个表现——**不是 ucrtbase.dll 损坏**，
  别跑去修 C++ 运行库或 `sfc` / `DISM`（那是这条签名的经典红鲱鱼）。
- `~/.glzr/glazewm/errors.log` 里**没有**对应记录 → 崩在日志系统初始化之前，
  属于极早期初始化就 abort。

**关键证据**：每次开机都在**同一时间点、同一偏移**崩溃：

| 开机 | 崩溃 | 间隔 |
|---|---|---|
| 9/16 21:25:09 | 21:25:15 | 6.2 s |
| 9/18 10:35:23 | 10:35:28 | 5.6 s |
| 9/18 15:02:22 | 15:02:27 | 5.0 s |
| 9/23 16:34:44 | 16:34:50 | 5.9 s |
| 9/24 09:32:21 | 09:32:26 | 5.4 s |
| 9/24 12:38:34 | 12:38:40 | 6.1 s |

**6/6 次开机全崩**，WER 存储段哈希完全一致（`b851d482ab99925d`），而同一时段
**手动**启动的实例（开机后 1 分钟、shell 已就绪）运行完全正常——同一版本、同样被
Windhawk 注入，只是**时机**不同。

**根因**：`Delay=0` 使任务在**登录瞬间**就拉起 GlazeWM。此时 `explorer.exe` 才启动
几秒，shell / DWM / COM 子系统均未就绪，GlazeWM 早期初始化直接 panic。
HKCU Run 键看起来「晚」，但它由 explorer **在 shell 初始化之后**才处理，反而落在
危险窗口之外——也就是说这是 9/13 改造引入的**新问题**，且被 9/13 的目标
（yasb 启动太晚）掩盖了。

**为什么 `LastTaskResult` 一直是 0（排查时最容易被骗的地方）**：
`launch-glazewm.vbs` 用 `sh.Run ..., 0, False`（**不等待、无错误捕获**），wscript 只要
成功「发起」启动请求就退出并返回 0，glazewm 之后死没死它一无所知；加上任务
`RestartCount=0`（无重试），崩了就彻底没人管。**「任务返回 0」≠「程序活着」**。

**修复**：给 `LogonTrigger` 加 `Delay=PT15S`（登录后 15 秒再启动）。

依据是实测的登录时间线（2026-09-24 12:38:34 那次登录）：

| 偏移 | 事件 |
|---|---|
| +4.0 s | `explorer.exe` 启动 |
| **+6.1 s** | ← **`Delay=0` 时 GlazeWM 就在此刻崩溃** |
| +45.2 s | 最早的 Run 项应用（`msedge`） |
| +47~48 s | `RBTray` / `memreduct` / `Everything` |
| +49~55 s | `QQ` |
| +52 s | `steam` |
| +59 s | `wallpaper64` |
| +61~67 s | `localsend` / `RazerAppEngine` |

崩溃窗口只在 **+5~6 秒**，而 Run 项应用要到 **+45 秒**才出现——中间有近 40 秒的安全区。
所以 `PT15S` 既避开了崩溃窗口，又比所有 Run 项应用**早约 30 秒**，
原本「yasb 不要最后启动」的目标仍然成立。

> 💡 **教训**：`Delay=0` 的登录触发器不等于「更好」，它把程序扔进系统组件尚未就绪的
> 竞态窗口。**「尽早」要有一个下限**，而不是无限提前。

**排查过程中走过的弯路**（记录下来避免重蹈）：

1. 一度怀疑是 Windhawk 的 `translucent-windows` mod（`Include=*`，注入所有进程）。
   崩溃时的 `LoadedModule` 列表里确实有 `windhawk.dll` 和
   `translucent-windows_1.8.1_434437.dll`——**但这不是根因**：正常运行中的 glazewm
   同样加载了它。已顺手把 `glazewm.exe` 加进该 mod 的 `Exclude`（减小竞态窗口），
   配置路径：`HKLM\SOFTWARE\Windhawk\Engine\Mods\translucent-windows`。
2. 中途曾回退到 HKCU Run——实测链路可达，但会让 yasb 重新掉回队尾（即 9/13 要解决的
   那个问题），属于双重损失，已撤销。

> ⚠️ **残留项**：`HKCU\...\Explorer\StartupApproved\Run` 下仍留有 `GlazeWM` 记录
> （`02 00 00 ...` = 启用）。这是 Explorer 的历史记录，Run 键中已无该项，**无害**。
> 留着还有个好处：将来若再次往 Run 键添加 `GlazeWM`，它会自动继承「启用」状态，
> 不会被静默禁用。

## 验证方法

```powershell
# 0. 触发器延迟是否为 PT15S
(Get-ScheduledTask -TaskName GlazeWM).Triggers[0].Delay

# 1. 任务是否成功（0 = 成功，2147943140 = 740 权限错误）
#    ⚠️ 0 只代表 wscript 成功「发起」了启动，不代表 glazewm 活着 —— 必须再查进程！
Get-ScheduledTaskInfo -TaskName GlazeWM | Select-Object LastRunTime, LastTaskResult

# 1b. 有没有开机崩溃（这是 LastTaskResult=0 掩盖不了的部分）
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; StartTime=(Get-Date).AddDays(-7)} -EA SilentlyContinue |
  Where-Object { $_.Message -match 'glazewm' } | Select-Object TimeCreated, Id

# 2. 端到端：杀掉全部进程模拟全新登录，再触发任务
Get-Process glazewm,yasb -EA SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName GlazeWM
Start-Sleep -Seconds 10
Get-Process glazewm,yasb -EA SilentlyContinue | Select-Object ProcessName,Id,StartTime | Sort-Object StartTime

# 3. 开机后对比启动时间线（glazewm 应早于 Steam / WallpaperEngine / Edge）
Get-Process glazewm,yasb,steam,msedge,explorer -EA SilentlyContinue |
  Select-Object ProcessName,Id,StartTime | Sort-Object StartTime
```

判定标准：

1. **glazewm 的 `StartTime` 早于其余 Run 项应用**（`PT15S` 仍应比 +45 秒的 Run 项早约 30 秒），
   且 yasb 紧随其后（同秒级）；
2. **`1b` 查不到新的崩溃记录**（`Application Error` / `ucrtbase.dll` / `0xc0000409`）。

## 回滚

```powershell
# 1. 删除计划任务
Unregister-ScheduledTask -TaskName GlazeWM -Confirm:$false
# 2. 恢复 Run 键项
reg import "%USERPROFILE%\Projects\dotfiles\system-tweaks\tweaks\glazewm-startup\HKCU-Run-20260913-005910.reg"
# 3. 删包装脚本（可选）
Remove-Item "%USERPROFILE%\.glzr\launch-glazewm.vbs"
```

## 本目录文件

| 文件 | 说明 |
|---|---|
| `README.md` | 本文档 |
| `launch-glazewm.vbs` | 启动包装脚本的归档副本（实际生效位置 `~/.glzr/`） |
| `GlazeWM-task.xml` | 计划任务定义导出（`Export-ScheduledTask`），**含 `<Delay>PT15S</Delay>`**，可用于重建任务 |
| `HKCU-Run-20260913-005910.reg` | 改造前的 `HKCU\...\Run` 完整备份 |
| ~~`config.yaml.snapshot`~~ | 归档时点的 `glazewm/config.yaml` 快照，**已于 2026-09-13 删除**（原因见下方「相关位置」） |

## 重建步骤（新机器 / 恢复）

1. 确认 GlazeWM 已安装，且 `~/.glzr/glazewm/config.yaml` 含 `startup_commands: ['shell-exec yasb']`
2. 把 `launch-glazewm.vbs` 放到 `~/.glzr/`，**按实际路径修改其中的 exe 路径**
3. 导入计划任务（比手写更可靠，XML 里已含 `Delay=PT15S`）：
   ```powershell
   schtasks /create /tn "GlazeWM" /xml ".\GlazeWM-task.xml"
   ```
   或按上表用 `New-ScheduledTask*` 系列命令重建。
   **⚠️ 别漏掉触发器延迟**——用 `New-ScheduledTaskTrigger -AtLogOn` 重建时，`Delay`
   要手动赋值（`$trg.Delay = 'PT15S'`），新建的触发器**默认延迟 0**，会重现坑 4。
4. 确认 `HKCU\...\Run` 中**没有**重复的 `GlazeWM` 项（否则会启动两次）
5. 按「验证方法」做端到端测试

## 相关位置

| 内容 | 位置 |
|---|---|
| GlazeWM 配置（**权威源**） | `~/Projects/my_dot/dotfiles/glazewm/config.yaml` |
| GlazeWM 配置（实际生效） | `~/.glzr/glazewm/config.yaml`（用 `my_dot\sync-dotfiles.ps1` 部署） |
| yasb 配置（**权威源**） | `~/Projects/my_dot/dotfiles/yasb/` → `~/.config/yasb/` |
| 启动包装脚本 | `~/Projects/my_dot/dotfiles/glazewm/launch-glazewm.vbs` → `~/.glzr/launch-glazewm.vbs` |

> 📌 **2026-09-13 迁移**：本目录原先存放的 `config.yaml.snapshot` 已删除 —— 它是一份
> **手动快照**，没有任何机制保证与生效配置同步（果然很快就过期了）。GlazeWM / yasb 的
> 配置本体现已统一由 `my_dot` 仓库的 `dotfiles/` 管理（见上表），本目录只保留
> **启动方式**的处理记录。
