"""把导出副本里的本机路径 / 账号 / 机器标识换成占位符。

本仓库是「只读发布镜像」：`tools/export.ps1` 从两个私有上游仓库拷文件过来，
拷完就跑这个脚本做清洗。**不要直接改本仓库里的配置文件** —— 下次导出会覆盖。

用法（在仓库根目录）：
    python tools/sanitize.py

幂等：已经是占位符的文件再跑一遍不会变化。
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPO = r"%USERPROFILE%\Projects\dotfiles"

# ---------------------------------------------------------------- 通用替换表
# 纯字面替换，**先长后短**（短规则会吃掉长规则的前缀）
COMMON: list[tuple[str, str]] = [
    # --- 上游 Themes 仓库（产线，不在本仓库）---
    (r"C:\Users\Agustin\Themes\tokens\tokens.yaml", "palette/tokens.yaml"),
    (r"C:\Users\Agustin\Themes", r"%USERPROFILE%\Themes"),
    ("/mnt/c/Users/Agustin/Themes", "/mnt/c/Users/<YourName>/Themes"),
    # --- my_dot / system-tweaks 的旧位置 → 本仓库 ---
    (r"C:\Users\Agustin\Projects\system-tweaks", REPO + r"\system-tweaks"),
    (r"C:\Users\Agustin\Projects\my_dot\dotfiles", REPO),
    (r"C:\Users\Agustin\Projects\my_dot", REPO),
    # --- 具体路径 ---
    (r"C:\Users\Agustin\.config\yasb", r"%USERPROFILE%\.config\yasb"),
    (r"C:\Users\Agustin\.glzr", r"%USERPROFILE%\.glzr"),
    (r"C:\Users\Agustin\AppData\Local\Microsoft\WindowsApps\wt.exe", "wt.exe"),
    (r"C:\Users\Agustin\AppData\Local\Temp", "%TEMP%"),
    (r"C:\Users\Agustin\AppData", "%APPDATA%"),
    # --- 账号名 ---
    (r"WOOYUN\Agustin", r"DOMAIN\Username"),
    ("/mnt/c/Users/Agustin", "/mnt/c/Users/<YourName>"),
    # .reg 里反斜杠是双写的，先处理双写形式
    (r"C:\\Users\\Agustin", r"C:\\Users\\<YourName>"),
    (r"C:\Users\Agustin", r"C:\Users\<YourName>"),
    ("C:/Users/Agustin", "C:/Users/<YourName>"),
    ("C--Users-Agustin--", "C--Users-<YourName>--"),
]

WATERMARK = (
    r"# AUTO-GENERATED from C:\Users\Agustin\Themes\tokens\tokens.yaml "
    "— 不要手改，改 tokens 后跑 generate.py",
    "# AUTO-GENERATED from palette/tokens.yaml（上游 everforest-themes 仓库）"
    " — 不要手改，改 tokens 后重跑生成器",
)

SID_OLD = r"<UserId>S-1-5-21-1702525069-1725566650-4045054621-1001</UserId>"
SID_NEW = r"<UserId>S-1-5-21-0000000000-0000000000-0000000000-1000</UserId>"

REG_ICON = REPO + r"\system-tweaks\context-menu\run-pi-here.ico"


def read(path: pathlib.Path) -> tuple[str, str]:
    raw = path.read_bytes()
    # 必须靠 BOM 判断：UTF-16LE 里的 NUL 字节在 UTF-8 下是"合法"的，
    # 顺序试解码会把整份文件读成垃圾。
    if raw.startswith(b"\xff\xfe"):
        return raw.decode("utf-16"), "utf-16"
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def write(path: pathlib.Path, text: str, enc: str) -> None:
    path.write_bytes(text.encode(enc))


def expand_sz(value: str) -> str:
    """生成 .reg 的 REG_EXPAND_SZ 值：hex(2): + UTF-16LE + 结尾 00 00。"""
    data = value.encode("utf-16-le") + b"\x00\x00"
    hexes = [f"{b:02x}" for b in data]
    lines = [",".join(hexes[i:i + 25]) for i in range(0, len(hexes), 25)]
    return "hex(2):" + ",\\\r\n  ".join(lines)


def rewrite_reg(path: pathlib.Path) -> None:
    """Run-Pi-Here.reg：Icon 用 REG_EXPAND_SZ 存 %USERPROFILE%，command 用 PATH 里的 wt.exe。"""
    header = (
        r"Windows Registry Editor Version 5.00" + "\r\n\r\n"
        + r"; Run Pi Here —— 在文件夹 / 驱动器右键菜单里打开 pi（PowerShell 7 / pwsh）" + "\r\n"
        + r'; 命令: wt.exe -d "%V" pwsh -NoExit -Command "pi"（要求 wt.exe 在 PATH 里）' + "\r\n"
        + r"; Icon 用 REG_EXPAND_SZ（hex(2)）存 %USERPROFILE%，换机器也能展开：" + "\r\n"
        + r";   仓库需 clone 到 %USERPROFILE%\Projects\dotfiles" + "\r\n"
        + r";   路径不同就改 hex(2) 里的字符串后重新导入，或用 reg add 直接写" + "\r\n"
    )
    blocks = []
    for key in (r"Directory\Background", "Directory", "Drive"):
        blocks.append(
            "\r\n" + r"[HKEY_CURRENT_USER\Software\Classes\%s\shell\RunPiHere]" % key + "\r\n"
            + r'@="Run Pi Here"' + "\r\n"
            + r'"Icon"=' + expand_sz(REG_ICON) + "\r\n"
            + "\r\n" + r"[HKEY_CURRENT_USER\Software\Classes\%s\shell\RunPiHere\command]" % key + "\r\n"
            + r'@="wt.exe -d \"%V\" pwsh -NoExit -Command \"pi\""' + "\r\n"
        )
    path.write_bytes((header + "".join(blocks)).encode("utf-16"))


def main() -> None:
    changed: list[str] = []

    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix in {".png", ".ico", ".pak", ".vsix", ".gif"}:
            continue
        if path.parent.name == "tools":
            continue

        rel = path.relative_to(ROOT).as_posix()

        # 这两个文件直接整体重写，不做字面替换
        if rel == "system-tweaks/context-menu/Run-Pi-Here.reg":
            rewrite_reg(path)
            changed.append(rel)
            continue

        text, enc = read(path)
        orig = text
        text = text.replace(*WATERMARK)
        text = text.replace(SID_OLD, SID_NEW)
        for lit, rep in COMMON:
            text = text.replace(lit, rep)
        if text != orig:
            write(path, text, enc)
            changed.append(rel)

    print(f"清洗完成，改动 {len(changed)} 个文件：")
    for c in changed:
        print("  ", c)


if __name__ == "__main__":
    main()
