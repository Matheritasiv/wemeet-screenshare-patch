#!/bin/sh
# wemeet-wayland-launcher.sh —— 让腾讯会议在 Wayland 下通过 xdg-desktop-portal 共享屏幕
#
# 基于 AUR wemeet-bin 3.26.10.401-5 的 /usr/bin/wemeet，改动三处：
#   1. 删除 bwrap 的 --unshare-pid —— 否则 xdg-desktop-portal 无法反查客户端凭据，
#      点“共享屏幕”不会有任何反应。
#   2. 删除 export WEMEET_XWAYLAND=1 —— libscreen_share_module.so 里的
#      IsUseXDGDesktopPortal() 就是 getenv("WEMEET_XWAYLAND")=="1"，为 1 时
#      直接走旧 X11(XShm) 抓屏路径，portal 一次都不会被调用。
#   3. 用打过 patch.py Hunk 0 的 libscreen_share_module.so 覆盖原模块
#      （仅在 bwrap 的本进程 mount namespace 内，不修改 /opt 下的系统文件）——
#      Hunk 0 修 SelectSources/Start 的异步竞态（Sources not selected）。
#
# 注意：界面仍保持 X11 模式（XDG_SESSION_TYPE=x11 / 不设 WAYLAND_DISPLAY /
# QT_QPA_PLATFORM=xcb）。不要改成 XDG_SESSION_TYPE=wayland 却仍用 xcb，
# 那会让腾讯会议在 x_utils::SetWindowInputFocus → XSetInputFocus 处 SIGSEGV。
#
# 依赖：wemeet-bin、bubblewrap、打过 Hunk 0 的模块（见 docs/hyprland-xdph.md）
set -eu

FIX_LIB="${WEMEET_FIX_LIB:-$HOME/.local/lib/wemeet-fix/libscreen_share_module.so}"
MODULE=/opt/wemeet/bin/modules/screen_share/libscreen_share_module.so

[ -x /opt/wemeet/bin/wemeetapp ] || { echo "未找到腾讯会议：请先安装 wemeet-bin" >&2; exit 1; }
[ -f "$FIX_LIB" ] || { echo "缺少补丁模块 $FIX_LIB（见 docs/hyprland-xdph.md）" >&2; exit 1; }
command -v bwrap >/dev/null || { echo "需要 bubblewrap：sudo pacman -S bubblewrap" >&2; exit 1; }

# 补丁与二进制严格绑定；版本变化时提示重打，避免“点共享没反应”这种沉默失败
ver=$(pacman -Q wemeet-bin 2>/dev/null | awk '{print $2}' || true)
case "${ver:-}" in
    3.26.10.401-*) : ;;
    *) echo "⚠ wemeet-bin 版本为 ${ver:-未知}，本补丁仅针对 3.26.10.401-5，屏幕共享可能失效" >&2 ;;
esac

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_STYLE_OVERRIDE=fusion                                       # 自带 Qt 下字体全白的问题
export IBUS_USE_PORTAL=1                                              # fix ibus
export LD_LIBRARY_PATH="/usr/lib/wemeet:${LD_LIBRARY_PATH:-/usr/lib}" # 否则启动失败

USER_RUN_DIR="/run/user/$(id -u)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
FONTCONFIG_DIR="$CONFIG_DIR/fontconfig"
KDE_GLOBALS_FILE="$CONFIG_DIR/kdeglobals"
KDE_ICON_CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/icon-cache.kcache"
WEMEET_APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wemeetapp"
LD_PRELOAD_WRAP="${LD_PRELOAD:-}:/usr/lib/wemeet/libwemeetwrap.so"    # 缓解传输文件崩溃

if [ "$(basename "$0")" = 'wemeet-wayland-x11' ]; then
    # 强制纯 X11（调试用）
    export XDG_SESSION_TYPE=x11
    export EGL_PLATFORM=x11
    export QT_QPA_PLATFORM=xcb
    unset WAYLAND_DISPLAY
elif [ "$XDG_SESSION_TYPE" = 'wayland' ]; then
    # 与 AUR 原版一致：界面走 X11，但不设 WEMEET_XWAYLAND，让共享走 portal
    export QT_QPA_PLATFORM=xcb
    export XDG_SESSION_TYPE=x11
    unset WAYLAND_DISPLAY
fi

mkdir -p "$WEMEET_APP_DIR"
exec bwrap \
    --new-session \
    --unshare-user-try --unshare-uts --unshare-cgroup-try \
    --proc /proc \
    --ro-bind / / \
    --dev-bind /dev /dev \
    --bind /tmp /tmp \
    --ro-bind /dev/null /proc/cpuinfo \
    --tmpfs /sys/devices/virtual \
    --bind "$USER_RUN_DIR" "$USER_RUN_DIR" \
    --tmpfs /var \
    --tmpfs "$CONFIG_DIR" \
    --ro-bind-try "$KDE_GLOBALS_FILE" "$KDE_GLOBALS_FILE" \
    --ro-bind-try "$FONTCONFIG_DIR" "$FONTCONFIG_DIR" \
    --bind-try "$KDE_ICON_CACHE_FILE" "$KDE_ICON_CACHE_FILE" \
    --bind "$WEMEET_APP_DIR" "$WEMEET_APP_DIR" \
    --ro-bind "$FIX_LIB" "$MODULE" \
    --setenv LD_PRELOAD "$LD_PRELOAD_WRAP" \
    /opt/wemeet/bin/wemeetapp "$@"
