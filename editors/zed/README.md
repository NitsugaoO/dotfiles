# Everforest 主题 for Zed

把 Everforest hard（高对比）暗色色板映射到 Zed 的主题系统。
**语法高亮以 `themes/everforest/VSCode/everforest-hard-dark.json` 为参考**（与 nvim 主题同源），
UI 表面沿用本仓库的角色表（`themes/everforest/tokens.yaml`）。

文件：`everforest-hard-dark.json`（Zed 主题族 `Everforest Hard` / 主题名 `Everforest Hard Dark`）

## 生成

```bash
cd ~/Themes
python generator/generate.py --only zed     # 写归档 + 同步到 Zed 用户主题目录
python generator/generate.py --check        # 只校验模板渲染（14 个目标之一）
python generator/audit.py                   # 色值归属 + 与生效位置是否一致
```

- 源模板：`src/zed.json`（只写 `{{角色}}` / `{{角色_aNN}}`，**别直接改产物**）
- 归档：`themes/everforest/Zed/everforest-hard-dark.json`
- 生效位置（`generate.py` 的 `LIVE` 自动同步）：
  `%APPDATA%\Zed\themes\everforest-hard-dark.json`
  = `C:\Users\<你>\AppData\Roaming\Zed\themes\everforest-hard-dark.json`

## 安装 / 生效

1. 跑一次生成（见上）——文件会直接落到 Zed 的用户主题目录。
2. Zed 里 `ctrl-k ctrl-t`（theme selector）搜 `Everforest Hard Dark` 选中；
   或写进 `%APPDATA%\Zed\settings.json`：

   ```jsonc
   {
     "theme": {
       "mode": "dark",
       "light": "One Light",          // ThemeSelection 结构要求 light 也存在，不能只写 dark
       "dark": "Everforest Hard Dark"
     }
   }
   ```

3. 换机器：拷这一个 JSON 到同样目录即可，无其它依赖。

> 结构说明：`theme` 字段是一个 untagged enum —— 只写 `{"mode":"dark","dark":"…"}` 会
> 报 `data did not match any variant of untagged enum ThemeSelection` 并回退默认主题。

## 色值映射

### UI

| Zed | 角色 | hex |
|---|---|---|
| `editor.background` / `surface.background` | `背景` | `#272e33` |
| `panel.background` / `element.background` | `面板` | `#2e383c` |
| `elevated_surface.background` / `element.hover` | `浮层` | `#374145` |
| `border` / `element.selected` / `editor.invisible` | `边框` | `#414b50` |
| `title_bar` / `tab_bar` / `status_bar` / `toolbar` | `最深` | `#1e2326` |
| `tab.active_background` | `背景` | `#272e33` |
| `text` / `editor.foreground` | `正文` | `#d3c6aa` |
| `text.muted` / `icon.muted` | `次要` | `#9da9a0` |
| `text.placeholder` / `hint` | `更淡` | `#859289` |
| `text.disabled` / `hidden` / `ignored` | `最淡` | `#7a8478` |
| `text.accent` / `border.focused` / `pane.focused_border` | `强调` | `#a7c080` |
| `error.*` / `deleted.*` / `version_control.deleted` | `危险` | `#e67e80` |
| `warning.*` / `modified.*` / `conflict.*` | `注意` | `#dbbc7f` |
| `success.*` / `created.*` / `version_control.added` | `正常` | `#83c092` |
| `info.*` / `renamed.*` | `蓝` | `#7fbbb3` |

半透明一律用 `{{角色_aNN}}`（展开成 Zed 的 `#rrggbbaa`）：
`search.match_background` = `注意_a40`、`scrollbar.thumb` = `更淡_a33`、
`editor.active_line.background` = `浮层_a55`、`drop_target` = `强调_a33` 等。

### 语法高亮（对齐 VSCode 主题）

| Zed capture | VSCode scope | 角色 | hex |
|---|---|---|---|
| `comment` / `comment.doc`（斜体） | `comment` | `更淡` | `#859289` |
| `string` / `text.literal` | `string` | `注意` | `#dbbc7f` |
| `string.escape` | `constant.character.escape` | `强调` | `#a7c080` |
| `keyword` | `keyword` | `危险` | `#e67e80` |
| `function` | `entity.name.function` | `强调` | `#a7c080` |
| `type` / `variant` / `enum` / `constructor` | `entity.name.type` | `蓝` | `#7fbbb3` |
| `variable` / `property` / `punctuation` | `variable` | `正文` | `#d3c6aa` |
| `number` / `constant` / `boolean` | `constant.numeric` | `紫` | `#d699b6` |
| `operator` / `tag` / `selector` | `keyword.operator` / `entity.name.tag` | `偏高` | `#e69875` |
| `attribute` | `entity.other.attribute-name` | `注意` | `#dbbc7f` |
| `namespace` / `label` / `preproc` | `entity.name.namespace` | `正常` | `#83c092` |
| `variable.special` / `string.special.symbol` | `constant.language` | `紫` | `#d699b6` |
| `diff.plus` / `diff.minus` | — | `正常` / `危险` | |

> ⚠️ 仓库里存在**两套**语法约定：Pi 主题用 vim 那套（字符串=green、函数=yellow、类型=aqua、
> 变量=blue），VSCode / nvim / Zed 用上表这套。改之前先确认目标应用跟哪一套。

## 备注

- `src/zed.json` 覆盖 schema v0.2.0 的全部键 + One Dark 里的 9 个较新键
  （`version_control.*`、`search.active_match_background`、`editor.hover_line_number`），
  本地 Zed 1.27 的二进制里都有这些字段。
- Zed 的 8 位色是 **`#rrggbbaa`**（alpha 在后），VSCode/WPF 是 `#aarrggbb`（alpha 在前）；
  `audit.py` 对 8 位色取「首 6 位或尾 6 位」任一命中色板即判合规。
- `players` 给了 8 个协作光标色（强调 / 蓝 / 紫 / 注意 / 正常 / 偏高 / 危险 / 更淡）。
