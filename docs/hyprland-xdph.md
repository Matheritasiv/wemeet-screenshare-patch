# Hyprland / xdg-desktop-portal-hyprland 说明（实测于 Omarchy 4.0.0）

本文记录在 **Hyprland + xdg-desktop-portal-hyprland（下称 XDPH）** 上让腾讯会议
`3.26.10.401` 走 portal 共享屏幕所需的三件事。已在以下环境实测通过：

```
Arch Linux（Omarchy 4.0.0）/ Hyprland 0.57.2
wemeet-bin 3.26.10.401-5
xdg-desktop-portal 1.22.1 / xdg-desktop-portal-hyprland 1.5.0
pipewire 1.6.11 / wireplumber 0.5.19
```

## 症状

点「共享屏幕」后弹出**一个**选择器，选完屏幕/窗口后就再也没有任何反应，
会议里也没有画面。`journalctl --user -u xdg-desktop-portal-hyprland` 中
**没有任何** `[screencopy] New session` 记录——说明 portal 从未被调用。

## 为什么 Hunk 0 还不够

`patch.py` 的 Hunk 0 只解决 `SelectSources` / `Start` 的异步竞态。但 AUR
`wemeet-bin` 的启动脚本 `/usr/bin/wemeet` 在 Wayland 会话下还会做两件事，
它们会让共享**根本走不到 portal**：

### 1. `WEMEET_XWAYLAND=1` 是“关闭 portal”的总开关

`/opt/wemeet/bin/modules/screen_share/libscreen_share_module.so` 中
（本版本偏移 `0x41fac0`）反汇编可见：

```asm
41facb: lea   0x505b5e(%rip),%rdi   # "WEMEET_XWAYLAND"
41fad2: call  getenv@plt
...
41fdfb: lea   0x4f9b03(%rip),%rsi   # "1"
41fe06: call  operator==(string, const char*)
```

即该函数（源码里的 `IsUseXDGDesktopPortal()` / `IsXWayland()`）只做一件事：

```c
return getenv("WEMEET_XWAYLAND") == "1";
```

为 `1` 时走旧 X11 (`XShmGetImage`) 抓屏路径。在 Hyprland 上 XWayland 根窗口
是空的，于是你看到的“选择器”其实是**腾讯会议自己的 X11 选择器**，抓到的
永远是空画面。所以必须**去掉** `export WEMEET_XWAYLAND=1`。

### 2. `bwrap --unshare-pid` 让 portal 认不出客户端

`/usr/bin/wemeet` 用 bubblewrap 包了一层，其中 `--unshare-pid` 会造成
PID 命名空间隔离，`xdg-desktop-portal` 无法通过 PID 反查发起者的凭据，
表现同样是「点共享屏幕没有任何反应」。删掉这一项即可
（与 AUR 评论区 2026-06-28 的建议一致）。

### 3. 不要靠改 `XDG_SESSION_TYPE` 打开 portal

把 `XDG_SESSION_TYPE` 改成 `wayland`、保留 `WAYLAND_DISPLAY`、但 Qt 仍用
`xcb`（所谓“半 Wayland 半 X11”）**会崩溃**：进入会议时腾讯会议会走
Wayland 的窗口管理路径却拿着一个空的 X Display，于是在

```
x_utils::SetWindowInputFocus → XSetInputFocus → _XGetRequest → SEGV
```

处 SIGSEGV。**保持 AUR 原版的 X11 伪装**（`XDG_SESSION_TYPE=x11`、
`unset WAYLAND_DISPLAY`、`QT_QPA_PLATFORM=xcb`），只去掉 `WEMEET_XWAYLAND`
即可：界面仍是 X11 模式（稳定），屏幕共享走 portal + PipeWire。

## 已实测可用的组合

1. `patch.py` 只打 **Hunk 0**（`Hunk 1a` / `Hunk 1b` 在 XDPH 下不需要，
   打了反而可能出现颜色异常）；
2. 启动器 = 原版 `/usr/bin/wemeet` 基础上：
   - 删除 `--unshare-pid`
   - 删除 `export WEMEET_XWAYLAND=1`
   - 用 `bwrap --ro-bind <打过 Hunk 0 的 libscreen_share_module.so> /opt/wemeet/bin/modules/screen_share/libscreen_share_module.so`
     只在本进程内替换该模块（**不修改 /opt 下的系统文件**）
3. 从该启动器打开腾讯会议 → 点「共享屏幕」→ 出现合成器的选屏器
   （Hyprland 下是 `hyprland-preview-share-picker` 或 `hyprland-share-picker`）
   → 选择后立即开始共享。

可直接使用：[`tools/wemeet-wayland-launcher.sh`](../tools/wemeet-wayland-launcher.sh)。

```shell
# 1) 准备补丁模块（只打 Hunk 0）
mkdir -p ~/.local/lib/wemeet-fix
cp /opt/wemeet/bin/modules/screen_share/libscreen_share_module.so ~/.local/lib/wemeet-fix/
python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("p", "patch.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
h = m.PATCHES["bin/modules/screen_share/libscreen_share_module.so"]
m.patch_file(f"{__import__('os').path.expanduser('~')}/.local/lib/wemeet-fix/libscreen_share_module.so", [h[0]])
PY

# 2) 安装启动器
install -Dm755 tools/wemeet-wayland-launcher.sh ~/.local/bin/wemeet-wayland
~/.local/bin/wemeet-wayland
```

## 已知限制

- 补丁严格绑定 `wemeet-bin 3.26.10.401-5`：腾讯会议一升级就必须重新审偏移；
- 结束共享的悬浮工具栏在 Hyprland 上仍可能被透明 overlay 窗口盖住点不到
  （与 WM 相关，与本补丁无关）；
- 本文只针对 XDPH。其他后端（gnome / kde / wlr）请参考各自上游文档。
