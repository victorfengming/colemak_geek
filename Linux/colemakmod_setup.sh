#!/usr/bin/env bash
# colemakmod：标准 us(colemak) + CapsLock<->Backspace + 左Ctrl<->右Ctrl
#
# 修复：
#   1) 不再覆盖/破坏 Fcitx 配置，保留搜狗输入法；仅关闭 Fcitx 对系统 XKB 的覆盖。
#   2) Ctrl/Alt 等快捷键与普通输入一样遵循 Colemak，不再在按 Ctrl 时切回 QWERTY。
#   3) 使用标准 us(colemak) 的 O 键映射：物理“;”键输出 o，物理“'”键仍输出 '。
#
# 适用：Ubuntu + X11 + Fcitx4/搜狗输入法
# 用法：sudo bash colemakmod_setup_fixed.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root 权限，请用：sudo bash $0"
    exit 1
fi

# sudo 调用者
REAL_USER="${SUDO_USER:-}"
[ -n "$REAL_USER" ] || REAL_USER="$(logname 2>/dev/null || true)"
[ -n "$REAL_USER" ] || {
    echo "无法确定当前桌面用户，请使用普通用户执行 sudo bash $0"
    exit 1
}
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
REAL_UID="$(id -u "$REAL_USER")"
[ -n "$REAL_HOME" ] || REAL_HOME="/home/$REAL_USER"

backup_file() {
    local f="$1"
    [ -f "$f" ] || return 0
    cp -a "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
}

# -----------------------------------------------------------------------------
# 1) XKB：系统布局保持标准 us(colemak)，这里只叠加 3 个按键交换。
#    这样 GNOME/Fcitx 仍然识别为标准 Colemak，不会看到一个陌生的自定义布局名。
# -----------------------------------------------------------------------------
XKB_FILE="/usr/share/X11/xkb/symbols/colemakmod"
backup_file "$XKB_FILE"
cat > "$XKB_FILE" <<'XKBEOF'
partial modifier_keys
xkb_symbols "swaps" {
    // 标准 us(colemak) 本身已经把 CapsLock 设为 Backspace；这里显式固定。
    replace key <CAPS> { type[Group1] = "ONE_LEVEL", [ BackSpace ] };

    // 原 Backspace 变成 CapsLock。
    replace key <BKSP> { type[Group1] = "ONE_LEVEL", [ Caps_Lock ] };
    modifier_map Lock { <BKSP> };

    // 左 Ctrl <-> 右 Ctrl。
    replace key <LCTL> { [ Control_R ] };
    replace key <RCTL> { [ Control_L ] };
    modifier_map Control { <LCTL>, <RCTL> };
};
XKBEOF

# 编译检查。字母布局来自标准 us(colemak)，因此 Ctrl/Alt 快捷键也天然按 Colemak 解析。
if command -v xkbcomp >/dev/null 2>&1; then
    TMPDIR_XKB="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_XKB"' EXIT
    cat > "$TMPDIR_XKB/test.xkb" <<'XKBTEST'
xkb_keymap {
    xkb_keycodes  { include "evdev+aliases(qwerty)" };
    xkb_types     { include "complete" };
    xkb_compat    { include "complete" };
    xkb_symbols   { include "pc+us(colemak)+colemakmod(swaps)+inet(evdev)" };
    xkb_geometry  { include "pc(pc105)" };
};
XKBTEST
    if ! xkbcomp -w 0 -I/usr/share/X11/xkb "$TMPDIR_XKB/test.xkb" "$TMPDIR_XKB/test.xkm" >/dev/null 2>&1; then
        echo "错误：Colemak + colemakmod(swaps) XKB 编译失败，未继续修改系统设置。"
        exit 1
    fi
fi

echo "[1/6] 标准 Colemak + 按键交换已写入并通过 XKB 检查"

# -----------------------------------------------------------------------------
# 2) 系统/GNOME 只使用标准 us+colemak，不再注册/使用自定义布局名 colemakmod。
# -----------------------------------------------------------------------------
if [ -f /etc/default/keyboard ]; then
    backup_file /etc/default/keyboard
fi
cat > /etc/default/keyboard <<'EOFKEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="colemak"
XKBOPTIONS=""
BACKSPACE="guess"
EOFKEYBOARD

echo "[2/6] /etc/default/keyboard 已恢复为标准 us / colemak"

# 旧脚本把 GNOME input-sources 整体设成 [('xkb','colemakmod')]。
# 这里只在检测到旧值时把 colemakmod 修回 us+colemak；其他输入源原样保留。
if command -v gsettings >/dev/null 2>&1 && [ -S "/run/user/$REAL_UID/bus" ]; then
    GS=(runuser -u "$REAL_USER" -- env HOME="$REAL_HOME" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" gsettings)
    CURRENT_SOURCES="$(${GS[@]} get org.gnome.desktop.input-sources sources 2>/dev/null || true)"
    if [[ "$CURRENT_SOURCES" == *"colemakmod"* ]]; then
        FIXED_SOURCES="${CURRENT_SOURCES//colemakmod/us+colemak}"
        "${GS[@]}" set org.gnome.desktop.input-sources sources "$FIXED_SOURCES" 2>/dev/null || true
        echo "[3/6] GNOME input-sources 已把旧 colemakmod 修回 us+colemak"
    else
        echo "[3/6] GNOME input-sources 未发现旧 colemakmod，保持不变"
    fi
else
    echo "[3/6] 当前无法访问 GNOME gsettings，会话登录后由标准 Colemak 配置接管"
fi

# -----------------------------------------------------------------------------
# 3) Fcitx4 / 搜狗：只修改 X Keyboard 插件的一项，不覆盖整个配置文件。
#    旧脚本会把 fcitx-xkb.config 整个文件写成两行；如果检测到这种情况，
#    优先从旧脚本留下的 .bak 恢复，再做最小修改。
# -----------------------------------------------------------------------------
F4_FILE="$REAL_HOME/.config/fcitx/conf/fcitx-xkb.config"
if [ -d "$REAL_HOME/.config/fcitx" ] || command -v fcitx >/dev/null 2>&1; then
    mkdir -p "$(dirname "$F4_FILE")"

    # 恢复旧脚本可能破坏的配置。
    if [ -f "$F4_FILE" ]; then
        NONEMPTY_LINES="$(grep -cve '^[[:space:]]*$' "$F4_FILE" || true)"
        if [ "$NONEMPTY_LINES" -le 2 ] \
           && grep -q '^\[X Keyboard\][[:space:]]*$' "$F4_FILE" \
           && grep -q '^OverrideSystemXKBSettings=False[[:space:]]*$' "$F4_FILE"; then
            if [ -f "$F4_FILE.bak" ]; then
                cp -a "$F4_FILE.bak" "$F4_FILE"
                echo "      已从旧脚本备份恢复 fcitx-xkb.config"
            fi
        fi
    fi

    backup_file "$F4_FILE"

    # 只 patch [X Keyboard] 下的 OverrideSystemXKBSettings，不碰其他键。
    TMP_F4="$(mktemp)"
    awk '
        BEGIN { insec=0; sec_seen=0; key_written=0 }
        /^\[X Keyboard\][[:space:]]*$/ {
            if (insec && !key_written) {
                print "OverrideSystemXKBSettings=False"
                key_written=1
            }
            insec=1
            sec_seen=1
            print
            next
        }
        /^\[[^]]+\][[:space:]]*$/ {
            if (insec && !key_written) {
                print "OverrideSystemXKBSettings=False"
                key_written=1
            }
            insec=0
            print
            next
        }
        insec && /^OverrideSystemXKBSettings[[:space:]]*=/ {
            if (!key_written) {
                print "OverrideSystemXKBSettings=False"
                key_written=1
            }
            next
        }
        { print }
        END {
            if (!sec_seen) {
                if (NR > 0) print ""
                print "[X Keyboard]"
                print "OverrideSystemXKBSettings=False"
            } else if (insec && !key_written) {
                print "OverrideSystemXKBSettings=False"
            }
        }
    ' "$F4_FILE" 2>/dev/null > "$TMP_F4" || true

    # 文件原本不存在时，awk 输入不存在会为空；补一个合法配置。
    if [ ! -s "$TMP_F4" ]; then
        printf '[X Keyboard]\nOverrideSystemXKBSettings=False\n' > "$TMP_F4"
    fi
    install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 0644 "$TMP_F4" "$F4_FILE"
    rm -f "$TMP_F4"

    echo "[4/6] Fcitx4 保持启用，仅禁止其覆盖系统 XKB（搜狗配置不会被清空）"
else
    echo "[4/6] 未检测到 Fcitx4，跳过 Fcitx 配置"
fi

# -----------------------------------------------------------------------------
# 4) 确保搜狗使用的 Fcitx4 输入法环境仍然存在。
#    不修改 ~/.config/fcitx/profile，因此不会删除“搜狗拼音”输入法条目。
# -----------------------------------------------------------------------------
if command -v im-config >/dev/null 2>&1 && command -v fcitx >/dev/null 2>&1; then
    runuser -u "$REAL_USER" -- env HOME="$REAL_HOME" im-config -n fcitx >/dev/null 2>&1 || true
fi

XPROFILE="$REAL_HOME/.xprofile"
touch "$XPROFILE"
chown "$REAL_USER:$(id -gn "$REAL_USER")" "$XPROFILE"
backup_file "$XPROFILE"

# 删除我们自己旧的 marker，再重新写入，避免重复。
TMP_XPROFILE="$(mktemp)"
awk '
    BEGIN { skip=0 }
    /^# >>> colemakmod fcitx >>>$/ { skip=1; next }
    /^# <<< colemakmod fcitx <<<$/{ skip=0; next }
    !skip { print }
' "$XPROFILE" > "$TMP_XPROFILE"
cat >> "$TMP_XPROFILE" <<'EOFPROFILE'

# >>> colemakmod fcitx >>>
# 搜狗拼音依赖 Fcitx4；这些变量让 GTK/Qt/XIM 应用继续把输入交给 Fcitx。
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
# <<< colemakmod fcitx <<<
EOFPROFILE
install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 0644 "$TMP_XPROFILE" "$XPROFILE"
rm -f "$TMP_XPROFILE"

echo "[5/6] Fcitx/搜狗输入法环境已保留"

# -----------------------------------------------------------------------------
# 5) 登录后再次应用布局，避免 GNOME 或 Fcitx 启动顺序把布局改回去。
#    不强行改 GNOME 的 input-sources，以免把中文输入源/用户现有配置覆盖掉。
# -----------------------------------------------------------------------------
USER_BIN="$REAL_HOME/.local/bin"
AUTOSTART_DIR="$REAL_HOME/.config/autostart"
mkdir -p "$USER_BIN" "$AUTOSTART_DIR"

APPLY_SCRIPT="$USER_BIN/apply-colemakmod"
cat > "$APPLY_SCRIPT" <<'EOFAPPLY'
#!/bin/sh
# 登录后应用自定义 XKB；Fcitx 的 X Keyboard 插件已设置为不覆盖系统 XKB。
/usr/bin/setxkbmap -layout us -variant colemak -symbols 'pc+us(colemak)+colemakmod(swaps)+inet(evdev)'
EOFAPPLY
chmod 0755 "$APPLY_SCRIPT"
chown "$REAL_USER:$(id -gn "$REAL_USER")" "$APPLY_SCRIPT"

AUTOSTART_FILE="$AUTOSTART_DIR/colemakmod.desktop"
cat > "$AUTOSTART_FILE" <<EOFDESKTOP
[Desktop Entry]
Type=Application
Name=Colemak Mod Keyboard
Exec=$APPLY_SCRIPT
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOFDESKTOP
chmod 0644 "$AUTOSTART_FILE"
chown "$REAL_USER:$(id -gn "$REAL_USER")" "$AUTOSTART_FILE"

# 当前 X11 会话立即应用。
APPLIED_NOW=0
if [ -n "${DISPLAY:-}" ]; then
    USER_XAUTH="${XAUTHORITY:-$REAL_HOME/.Xauthority}"
    if runuser -u "$REAL_USER" -- env \
        HOME="$REAL_HOME" \
        DISPLAY="$DISPLAY" \
        XAUTHORITY="$USER_XAUTH" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
        /usr/bin/setxkbmap -layout us -variant colemak -symbols 'pc+us(colemak)+colemakmod(swaps)+inet(evdev)' >/dev/null 2>&1; then
        APPLIED_NOW=1
    fi
fi

# 让正在运行的 Fcitx4 重新读取“不要覆盖 XKB”的设置。
if command -v fcitx-remote >/dev/null 2>&1 && pgrep -u "$REAL_USER" -x fcitx >/dev/null 2>&1; then
    if [ -n "${DISPLAY:-}" ]; then
        USER_XAUTH="${XAUTHORITY:-$REAL_HOME/.Xauthority}"
        runuser -u "$REAL_USER" -- env \
            HOME="$REAL_HOME" \
            DISPLAY="$DISPLAY" \
            XAUTHORITY="$USER_XAUTH" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
            fcitx-remote -r >/dev/null 2>&1 || true
    fi
fi

if [ "$APPLIED_NOW" -eq 1 ]; then
    echo "[6/6] 当前 X11 会话已立即应用标准 Colemak + 按键交换"
else
    echo "[6/6] 已配置登录自动应用；当前会话未能立即切换，注销后会生效"
fi

echo ""
echo "完成。三个修复点："
echo "  - 搜狗/Fcitx4 配置不再被脚本整体覆盖"
echo "  - Ctrl/Alt 快捷键按 Colemak 字母位置工作，不再切回 QWERTY"
echo "  - Colemak 的 o 已恢复：物理 ; 键 -> o，物理 ' 键 -> '"
echo ""
echo "建议执行完后注销并重新登录一次，让 Fcitx 和登录环境完全重载。"
echo "验证："
echo "  setxkbmap -query    # 应看到 layout: us / variant: colemak"
echo "  xev    # 检查 ; 位置是否为 o，以及左右 Ctrl"
