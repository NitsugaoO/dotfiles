# Everforest 主题 for 鼠标光标

把 [Jepri Creations](https://www.deviantart.com/jepricreations) 的 **Windows 11 Cursor Concept v2.2**
（Windows 11 / macOS 风格的白·黑单色光标包）重染成 Everforest 的 **hard 暗色强调色 `#a7c080`**。

原包只有「忙碌 / 后台工作」两个动画光标带颜色（作者自带了 amber / green / indigo / red /
purple / sunset 等 10 套），静态箭头、I 型光标、手型等全是黑白色 —— 所以**只需要改两个 `.ani`**。

## ⚠️ 授权与「不入库」的原因

原包 `Agreement.txt` 明确写着：

> You're NOT allowed to... **Distribute the pack files in any way.**
> *My cursor and myself (the author) should be credited clearly, add link to my DevianArt Page.*

因此本仓库**只保存生成脚本和安装件**，不保存任何 `.cur` / `.ani`：

| 入库 | 不入库（`.gitignore` 忽略，本地生成） |
|---|---|
| `generator/gen_cursor.py`、`Install.inf`、`install.ps1`、本文件 | `Cursors/base/*.cur`（15 个静态光标）、`Cursors/everforest/*.ani`（2 个动画光标） |

也就是说：**换机器要先把原包下载回来**，再跑一次生成器。这里只是把它当"取色模板"用，符合
"本机使用 + 个人修改"，不构成分发。

## 文件

| 文件 | 作用 |
|---|---|
| `generator/gen_cursor.py` | 读 `tokens.yaml` 的「强调」色，从原包重染两个动画光标；同时导出静态光标、渲染 `Install.inf` |
| `Install.inf` | Windows 标准的右键安装描述（复制到 `C:\Windows\Cursors` + 写注册表） |
| `install.ps1` | 一键安装（自动提权、复制、写注册表、`SPI_SETCURSORS` 立即生效；`-Uninstall` 回滚） |
| `base/`、`everforest/` | **生成物**，本地才有 |

## 用法

```bash
# 1) 准备原包：从 DeviantArt 下载 v2.2，解压后放到桌面
#    （默认路径 ~/Desktop/Windows.Cursor.Concept.v2.2.new，可用 --source 覆盖）

# 2) 生成（读 tokens.yaml 取色 → 重染 → 导出 inf）
python generator/gen_cursor.py

# 3) 安装（会自动弹 UAC）
powershell -NoProfile -ExecutionPolicy Bypass -File themes/everforest/Cursors/install.ps1
```

安装后在 `设置 → 蓝牙和其他设备 → 鼠标 → 其他鼠标设置 → 指针` 里选
`W11 Cursors Light HDPI everforest by Jepri Creations`。

也可以不用脚本：右键 `themes\everforest\Cursors\Install.inf` → 显示更多选项 → 安装（同样会提权，
并自动打开鼠标属性面板）。

### 校验

```bash
python generator/gen_cursor.py --check
# [OK] working.ani / busy.ani 主色 == tokens.yaml 强调色
# [OK] base/*.cur 15/15
# [OK] Install.inf 含方案名
```

### 换色

改 `themes/everforest/tokens.yaml` 的 `dark.强调` → 重跑 `gen_cursor.py` → 重跑 `install.ps1`
（或直接再右键一次 `Install.inf`）。**不需要**重跑 `generate.py`：光标的色值只来自 `tokens.yaml`，
颜色是写死在二进制的像素里的，没有任何"生效位置"要被覆盖。

### 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File themes/everforest/Cursors/install.ps1 -Uninstall
```

等价于：鼠标属性里选回系统默认 → 删 `C:\Windows\Cursors\W11_light_v2.2` →
删注册表 `HKCU\Control Panel\Cursors\Schemes` 下对应方案名。

## 实现原理

原包的 `.ani` 是 RIFF `ACON`：`anih`（37 帧）+ `LIST fram` 下 37 个 `icon` 块，**每个 icon 块其实
是一个完整的 `.cur`**（带热点），内含 32 / 48 / 64 / 96 四档尺寸，位图是**未压缩 32bpp BGRA**
（`biBitCount=32`、`biCompression=0`、`biHeight = 2×高`，表示 XOR + AND mask）。

所以不需要解码再编码：

1. 逐帧逐尺寸定位像素区（`icon块 + 40 字节BITMAPINFOHEADER`）；
2. 只重写 RGB 字节 —— 长度、块结构、帧数、热点、alpha、AND mask 全部原样；
3. 颜色映射按「彩色族」判定：色相落在源主色 ±55° 且饱和度 > 0.03 的像素才处理，
   把 H 平移到目标色、S/V 乘上目标色/源主色的比例，低饱和边缘按权重渐变插值
   （这样抗锯齿边不会留下绿色晕，也不会把白/灰主体改脏）；
4. 写回前校验 `anih` 位置与文件长度不变，否则拒绝写出。

## 附注

- 原包还有 `small`（小尺寸）和 `dark`（暗底）两档。本脚本固定用 `light/regular`（HDPI，适配
  100%–200% 缩放）；要换档位用 `--source <路径>` 指向对应目录即可，配色逻辑不变。
- 若系统里调大过「指针大小」（`HKCU\Control Panel\Cursors\CursorBaseSize`），Windows 会整体
  缩放这套光标，与脚本无关。
- 提权安装时 `SystemParametersInfo(SPI_SETCURSORS, …, SPIF_UPDATEINIFILE)` 会返回 `False`
  （该 API 不允许写 ini），所以 `install.ps1` 用 `fWinIni = 0` 触发重载，效果一样。

参考：[Windows 11 Cursor Concept v2.2 — Jepri Creations](https://www.deviantart.com/jepricreations)
