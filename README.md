# wemeet-screenshare-patch

腾讯会议 v3.26.10.401 linux 版本屏幕共享功能修复补丁



## 使用方法

**Step 1.** 设 `WEMEET_ROOT` 为腾讯会议根目录（例如 `/opt/wemeet`），运行

```
python3 /path/to/patch.py "$WEMEET_ROOT"
```

给库文件打补丁。

**Step 2.** 在 `$WEMEET_ROOT/wemeetapp.sh` 中加入

```
export LD_PRELOAD="/path/to/libhook.so"
```

即可。

**注意事项**：如果当前系统的 portal 后端没有颜色格式的问题（详见**技术细节**部分），用户可在打补丁前自行注释掉 `patch.py` 中的 `Hunk 1a` 和 `Hunk 1b`，此时只需第一步即可，无需 preload hook。



## 技术细节

### DBus 异步调用问题

根据 [xdg-desktop-portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html) 规范，客户端在发起屏幕共享请求的时候，需要依次执行

```
CreateSession
SelectSources
Start
OpenPipeWireRemote
```

这几个 DBus 异步调用，其中 `SelectSources` 和 `Start` 用于向 portal 后端请求屏幕捕获参数及显示器选择；若在调用 `Start` 时 `SelectSources` 没有**完成**执行，将会失败。

在当前版本的实现中，`Start` 的调用逻辑直接放在了 `SelectSources` 后面，而没有等待其调用完成；相对应的是 `OpenPipeWireRemote` 的调用正确地放到了回调函数 `onStartResponse` 中。这本质上是一个依赖竞态条件的未定义行为：`xdg-desktop-portal-gnome` 后端选择在 `SelectSources` 中立即设定屏幕捕获参数相关的内部状态，而在 `Start` 调用中弹窗等待用户选择显示器，这种设计掩盖了客户端的逻辑缺陷；但在 `xdg-desktop-portal-wlr` 后端默认配置情况下 `SelectSources` 同步调用外部程序 `slurp` 等待用户选择显示器，这将必然导致 `Start` 失败（除非在微秒级时间内完成选择）。

`patch.py` 中的 `Hunk 0` 通过修改 `libscreen_share_module.so` 中的控制流将 `Start` 调用移至 `onSelectSourcesResponse` 中，修复了异步链式调用逻辑。



### 缓冲区颜色格式转换

在 pipewire 格式协商阶段，客户端需要与 portal 后端协商包括颜色格式在内的一系列参数。在当前版本的实现中，客户端硬编码了

```
Id 12       (Spa:Enum:VideoFormat:BGRA)
Id 8        (Spa:Enum:VideoFormat:BGRx)
Id 13       (Spa:Enum:VideoFormat:ARGB)
Id 9        (Spa:Enum:VideoFormat:xRGB)
```

这几种颜色格式，且（可能？）没有提供对 DMA-Buf 方式的支持，只能使用 WL_SHM 方案。若 portal 后端没有提供对上述格式的支持，则协商阶段失败，UI 界面仍然显示屏幕录制状态，但并无视频数据流。

这部分补丁仅提供对 `RGBx` 格式的支持。`patch.py` 中的 `Hunk 1a` 将硬编码的 `08`（即 `BGRx`）修改为 `07`（即 `RGBx`），欺骗 pipewire 完成协商，同时在 [`param_changed`](https://docs.pipewire.org/structpw__stream__events.html) 回调函数中修改协商完成的值为 `08`，让客户端以 `BGRx` 格式处理缓冲区数据（似乎当前版本客户端没有处理 `xRGB` 格式的逻辑，只有 `BGRx` 一种处理路径？）。

客户端在 [`process`](https://docs.pipewire.org/structpw__stream__events.html) 回调中接收到缓冲区指针后，通过一系列同步调用转交给 `libxcast.so` 中的矩形区域拷贝函数处理，数据被顺序拷贝到另一个缓冲区（似乎是 X 缓冲区）中。`patch.py` 中 `Hunk 1a` 的其余部分与 `Hunk 1b` 共同劫持了这条拷贝路径，将数据转发给 `libhook.so` 中的 `getenv` 函数处理，该函数通过 `LD_PRELOAD` 方式进入进程空间。

`libhook.so` 的源码见 `hook/hook.asm`。其通过入参 `rdi` 的格式识别是 hook 调用还是真正的 C 库 `getenv()` 调用，后者直接转发到 C 库，前者则处理以下两种逻辑：

* 该 hook 调用来自 `libscreen_share_module.so`。此时保存源缓冲区指针至线程静态变量以供后续比对。
* 该 hook 调用来自 `libxcast.so`。此时比较源缓冲区指针与已保存的源缓冲区指针，如果不同则表明这是来自其他线程的无关调用，直接返还控制流；如果相同表明正是目标调用，清除该变量，然后执行转码路径。转码使用 AVX2 `shuffle` 指令高效处理，一轮循环可处理 64 个像素点。



## 致谢

本项工作感谢生成式人工智能 [Claude](https://claude.ai) 与 [Deepseek](https://chat.deepseek.com) 的协助。
