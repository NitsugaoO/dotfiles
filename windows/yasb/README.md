# yasb 状态栏配置

yasb 的布局与自定义 widget。配色由 `everforest-themes` 生成，**本目录只管行为**。

## 文件

| 文件 | 说明 |
| --- | --- |
| `config.yaml` | 布局与 widget 定义（权威源，含各组件状态色阈值） |
| `scripts/obs_status.py` | 查询 OBS 录制状态，供状态栏每秒轮询 |
| `scripts/obs_action.py` | 点击动作：开始录制 / 暂停恢复 / 停止并打开录像目录 |
| `patches/status_icons.py` | **注入 yasb 的 widget 子类**：让 CPU/GPU/内存/WiFi 的**图标**按状态变色 |
| `patches/install_patches.py` | 把上面的模块注入 `lib/library.zip`（**升级 yasb 后要重放**） |

> ⚠️ `styles.css` **不归本目录管**。它由 `everforest-themes`（`%USERPROFILE%\Themes`）的
> `tokens/generate.py` 从 `tokens/templates/yasb_styles.css` 渲染后**直接写入**
> `~\.config\yasb\styles.css`。要改配色请去那个仓库改 `tokens.yaml`。

## 部署

```powershell
cd %USERPROFILE%\Projects\dotfiles
.\sync-dotfiles.ps1
```

`config.yaml` → `~\.config\yasb\config.yaml`；`scripts\` → `~\.config\yasb\scripts\`。
yasb 开了 `watch_config`，改完自动重载。

> ⚠️ 部署脚本**不包含** `patches/` 的注入（那一步要写进 yasb 的安装包，见下一节），
> 但它会在末尾自动跑一次 `install_patches.py --check`：补丁缺失或过期时会以醒目的
> 提示给出重放命令。

## 状态色（图标变色）

状态栏右侧组件的**图标**会按状态变色；数字保持米白，不加底色块。

| 组件 | 状态 | 颜色 |
| --- | --- | --- |
| CPU / GPU / 内存 | `low` / `medium` / `high` / `critical`（阈值写在 `config.yaml`） | 绿 / 黄 / 橙 / 红 |
| 电池 | `full`+`high` / `medium` / `low` / `critical` | 绿 / 黄 / 橙 / 红 |
| WiFi | 有网 / 有连接但无外网 / 无连接（关 WiFi） | 绿 / 红 / 灰 |
| 音量 | 正常 / 静音或无设备 | 米白 / 灰 |

颜色本身来自 `everforest-themes` 的 `status/*` 语义角色（`tokens.yaml`），CSS 规则在
`tokens/templates/yasb_styles.css` 末尾的「负载状态色阶」一节 —— **要改配色去那个仓库**。

### 为什么要注入补丁

yasb 内置 widget 把状态 class 挂的位置并不统一：

| 组件 | 挂在 | 源码 |
| --- | --- | --- |
| 电池 | **图标** QLabel（`icon status-high`） | `battery.py:199` |
| 音量 | label 与 icon（`muted` / `no-device`） | `volume.py:588` |
| CPU / GPU / 内存 | **文字** label（`label status-high`） | `cpu.py:188` |
| WiFi | 没有状态 class，只有 `N/A` 文本 | `wifi.py` |

Qt 样式表**没有兄弟选择器、父选择器和伪元素**，所以 CSS 层面无法「看到文字上的状态，
再去给旁边的图标上色」。`patches/status_icons.py` 用四个子类覆写 `_update_label`，
把 `status-*` 也挂到图标上；同时必须调 `refresh_widget_style`，否则 Qt 不会重绘
（这就是 issue #142 那类「颜色停在启动档位」的成因）。

WiFi 三态另外做了判定：yasb 自带的 `WiFiWorker` 只认 `INTERNET_ACCESS` 的连接，
所以「关掉 WiFi」和「连上路由器但没外网」在它眼里都是 `Disconnected`。补丁改看所有
连接 profile 的 `NetworkConnectivityLevel`（`3` 有外网 / `1-2` 无外网 / `0` 无连接）。

### 装 / 重放补丁

yasb 用 cx_Freeze 打包，`core.*` 全在 `lib/library.zip` 里，而 `WidgetBuilder` 只会从
`core.widgets.*` 导入 widget，所以补丁必须写进这个 zip：

```powershell
python %USERPROFILE%\Projects\dotfiles\yasb\patches\install_patches.py
python ...\install_patches.py --check      # 只查状态
python ...\install_patches.py --restore    # 还原原始 zip
python ...\install_patches.py --clean      # 去除重复条目（需先退出 yasb）
```

不带参数就是注入（幂等）；`--check` 的退出码：`0` 正常 / `1` 缺失或过期，
`sync-dotfiles.ps1` 就是靠这个退出码来判断是否提醒你重放的。

- **scoop 升级 yasb 后必须重跑**（新版本目录里没有补丁，`type` 会指向不存在的模块）。
- 首次运行会把原包备份成同目录的 `library.zip.orig-backup`。
- yasb 运行时 zip 被占用，无法整体替换，脚本用**追加同名条目**实现更新
  （zipimport 顺序建索引，后者生效）；反复重放会让包变大，用 `--clean` 整理。
- 补丁生效需要 **`yasbc reload`**（或重启 yasb）：普通 config 热重载不会重新 import
  已经加载过的模块。

### 手动排查

```powershell
yasbc log        # 应能看到 "wifi state -> ok" 这类状态变更记录
```

## OBS 录制组件

状态栏右侧两个**互斥显示**的组件（视觉上永远只占一个位置）：

| 组件 | 何时显示 | 左键 | 右键 |
| --- | --- | --- | --- |
| `obs_idle`（灰） | OBS 在运行、但没在录制 | **开始录制** | — |
| `obs_rec`（红） | 录制中 | **暂停 / 恢复** | **停止录制** + 打开录像目录并选中最新文件 |

OBS 没运行（或 WebSocket 没启用）时两者都隐藏 —— 脚本连不上就输出空，配合 `hide_empty` 生效。

**左键是智能的**：未录制时发 `StartRecord`，录制中发 `ToggleRecordPause`。
刻意不用 `ToggleRecord`（切换语义），避免调用次数错位导致状态反转。

### 前置条件

1. **OBS 需要启用 WebSocket 服务器**：
   `工具 → WebSocket 服务器设置 → 勾选「启用 WebSocket 服务器」`（端口 4455）。
   密码自动从 OBS 的 `plugin_config\obs-websocket\config.json` 读取，**无需在这里配置**。
2. **Python 依赖**：`python -m pip install websocket-client`
3. 脚本必须用 **`pythonw.exe`** 调用（见下面第 3 条坑）。

### 踩过的坑（改这个组件前务必读）

**1️⃣ JSON 模式 + 空输出 → 状态栏显示 `{data[text]}` 字面量**

`return_format: json` 时，空输出会让 `json.loads` 失败 → `exec_data = None`，接着
`"{data[text]}".format(data=None)` 抛异常，YASB 的 `except` 分支直接把 `part` 原文写进
label；而 `hide_empty` 的隐藏逻辑就在异常点**下方**，被一并跳过。

**结论：必须用 `return_format: string`**（空字符串是 falsy 的，`hide_empty` 才能正常工作）。

**2️⃣ 非 ASCII 字符会让脚本静默崩溃**

YASB 用管道调用脚本，Windows 中文环境下子进程 stdout 编码是 **GBK**。
`print("⏺ 00:03")` 会 `UnicodeEncodeError` 直接崩溃、输出为空；
而 YASB 把 stderr 丢进了 `DEVNULL`，**你什么错误提示都看不到**，只看到组件不出现。

**结论：输出只用 ASCII**（脚本里另有 `sys.stdout.reconfigure(encoding="utf-8")` 兜底）。

**3️⃣ 点击时会闪出 cmd 窗口**

YASB 的轮询路径设了 `creationflags=CREATE_NO_WINDOW`，但**点击回调那条路径没有**
（`_cb_execute_subprocess`）。用 `python.exe` 就会弹控制台。

**结论：回调统一用 `pythonw.exe`**（Windows GUI 子系统，不分配控制台），
并保持 `use_shell: false`（否则会先起 cmd.exe，照样闪）。

**4️⃣ 超时必须远小于 `run_interval`，否则 widget 会“冻结”**

实测：在这台机器上连接一个 **已关闭** 的本地端口（`127.0.0.1:4455`，OBS 已退出）时，
SYN 被**静默丢弃**而非回 RST，`ConnectionRefusedError` 要等约 **2 秒**才抛出
（正常的本地回环拒绝是毫秒级）。（可能与 Clash Party / 安全软件的本地拦截有关。）

于是会踩上 yasb 定时器的陷阱：

```
脚本耗时 2.16s  >  run_interval 1000ms
  → 每轮 timer 触发时上一个 worker 还在跑，被 _worker.stop() 置 _is_running = False
  → 旧 worker 跑完因 _is_running 为假而 不 emit
  → widget 永远卡在最后一次成功的数据上
```

表现就是“关掉 OBS 后组件还显示 IDLE”，而且 `tasklist` 里会看到一堆 pythonw 进程堆积。

**结论：`TIMEOUT` / `PROBE_TIMEOUT` 必须远小于 1000ms**（现在分别是 `0.4` / `0.3`），
并在连接前先做一次端口预检。实测修好后单次耗时 ~400ms，进程不再堆积。

### 手动排查

```powershell
$py = "$env:USERPROFILE\scoop\apps\python\current\pythonw.exe"
$st = "$env:USERPROFILE\.config\yasb\scripts\obs_status.py"

& $py $st          # 未录制 → 空输出；录制中 → "REC 00:12"
& $py $st --idle   # OBS 在运行且未录制 → "IDLE"；OBS 没开 → 空
```

验证 OBS 侧的连接（能看到每秒一次的连断记录 = yasb 在正常轮询）：

```powershell
Select-String -Path "$env:APPDATA\obs-studio\logs\*.txt" -Pattern 'obs-websocket' |
  Select-Object -Last 6
```

### 也可以手动点

组件虽然小，但行为是完整的：**左键 = 开始/暂停，右键 = 停止并跳转到录像**。
录像目录从 OBS 配置的 `RecFilePath` 读取（当前是 `D:\Videos`），
右键停止后会等 1.5s 让 OBS 写完 moov，再用 `explorer /select` 高亮选中刚录的文件。
