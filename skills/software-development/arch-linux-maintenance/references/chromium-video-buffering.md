# Linux Chromium 在线视频卡顿：分层诊断与安全重启

适用于“B 站、YouTube 页面能开但视频持续缓冲”的 Linux/Chromium 场景。目标是先区分物理网络、代理分流、媒体 CDN、浏览器媒体管线与解码负载，再做最小修复。

## 1. 先建立可证伪的分层探针

不要看到缓冲就直接归因于 Wi-Fi、代理或硬件解码。按边界取证：

1. **物理链路**：连接、信号、丢包、路由、接口错误/丢弃。
   ```bash
   nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
   nmcli -t -f ACTIVE,SSID,SIGNAL,RATE dev wifi
   ip route
   ip -s link show dev wlp9s0
   ping -c 10 -W 2 223.5.5.5
   ```
2. **系统负载**：播放时看 CPU、可用内存与实时换页，而不是只看 swap 已占用多少。
   ```bash
   uptime
   free -h
   ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 15
   vmstat 1 8
   ```
   `swap used` 本身不证明卡顿；`vmstat` 中持续的 `si/so` 才说明换页压力。
3. **直连与代理吞吐**：用同一大文件做 direct/proxy 对照，避免拿首页 HTML 的 `speed_download` 代表视频带宽。
4. **真实媒体 CDN**：必须测速视频分片或观察浏览器正在连接的 `bilivideo.com` / `googlevideo.com`，因为网页 API 快不代表媒体 CDN 快。
5. **浏览器播放状态**：检查 `currentTime`、`readyState`、`buffered`、`droppedVideoFrames` 是否随时间前进。网络缓冲、解码掉帧和页面脚本卡死是不同故障。

## 2. 代理分流取证（Clash API）

当 Chromium 以 `--proxy-server=socks5://127.0.0.1:7891` 启动时，“所有请求先到 Clash”不等于“所有网站都走海外节点”。从控制 API 查看实际链路：

```bash
curl --noproxy '*' -sS http://127.0.0.1:9090/connections
curl --noproxy '*' -sS http://127.0.0.1:9090/proxies
```

重点记录：
- B 站媒体是否最终为 `DIRECT`；
- YouTube/Googlevideo 是否命中所选海外节点；
- 连接是否只有握手、还是下载字节持续增长；
- 是否存在多个代理进程，但只有一个真正监听端口。无监听、低占用的重复进程是清理项，不应在没有证据时当成缓冲根因。

延迟测试只证明节点能连通，不证明视频吞吐。必要时对候选节点做同一目标的实际媒体吞吐对照；切换选择器前记录当前节点，测试后恢复。

## 3. B 站真实分片测速

公开页面被反爬时，可通过公开 API 获取 `cid` 和 playurl，再以浏览器 User-Agent、B 站 Referer 下载一段媒体。不要把 HTTP 412 当成“网络慢”。

流程：
1. `https://api.bilibili.com/x/web-interface/view?bvid=<BVID>` 取 pages[0].cid；
2. `https://api.bilibili.com/x/player/playurl?bvid=<BVID>&cid=<CID>&qn=80&fnval=16` 取 `data.dash.video[0].baseUrl`；
3. 对 URL 做 Range 下载，并加：
   ```bash
   -A 'Mozilla/5.0 ... Chrome/... Safari/537.36' \
   -e 'https://www.bilibili.com/' -r 0-19999999
   ```
4. 记录 `time_starttransfer`、`time_total`、`size_download`、`speed_download`。

若真实分片可稳定达到数十 Mbps，而用户 Chromium 仍转圈，问题已从“校园网/国内 CDN”缩到浏览器会话、扩展、缓存或媒体管线。

## 4. 用隔离 Chromium 做差分播放

用独立 profile 打开同一视频，静音后调用 `video.play()`，间隔约 8 秒读取：

```javascript
const v = document.querySelector('video');
({
  current: v.currentTime,
  ready: v.readyState,
  network: v.networkState,
  paused: v.paused,
  buffered: Array.from({length: v.buffered.length}, (_, i) =>
    [v.buffered.start(i), v.buffered.end(i)]),
  dropped: v.getVideoPlaybackQuality().droppedVideoFrames,
  total: v.getVideoPlaybackQuality().totalVideoFrames,
  error: v.error && v.error.message
})
```

判断：
- `currentTime` 按墙钟前进、`readyState=4`、buffered 超前、掉帧接近 0：机器、链路和 Chromium 二进制基本正常；优先怀疑日常 profile/session/扩展。
- buffered 增长但 currentTime 不前进：页面状态、自动播放限制或媒体管线。
- currentTime 前进但 dropped 快速增加：解码/GPU/渲染问题，不是“下载缓冲”。
- CDN 下载字节不增长：回到代理节点、规则或链路排查。

## 5. 安全重启日常 Chromium

关闭用户浏览器是有可见副作用的；先征得同意。执行前：

```bash
# 确认根进程参数、运行时长
ps -p <ROOT_PID> -o pid,etimes,lstart,%cpu,%mem,args

# 确认会话文件存在
# ~/.config/chromium/Default/Sessions/
```

若 `restore_on_startup` 未明确启用，重启命令显式加 `--restore-last-session`。先 `SIGTERM` 并等待，禁止先上 `kill -9`：

```bash
kill -TERM <ROOT_PID>
for i in $(seq 1 30); do
  kill -0 <ROOT_PID> 2>/dev/null || break
  sleep 0.5
done
```

确认退出后，用原有代理、扩展参数加 `--restore-last-session` 重新启动。验证：
- 新根 PID、进程启动时间与 profile lock 已更新；
- 原视频站点连接重新出现；
- B 站和 YouTube 的媒体 CDN 连接命中预期链路；
- 连接下载字节在采样窗口内增长；
- 最终仍应让用户确认前台播放体验，不能把“连接建立”夸大成“画面已流畅”。

## 6. `buffered` 已满但 `currentTime` 不动：检查 VA-API

若浏览器页面能打开、媒体 CDN 已下载数据，并且播放器同时满足：

- `readyState=4`；
- `paused=false`；
- `buffered` 已明显超前甚至覆盖整段；
- 等待 5 秒后 `currentTime` 仍停在原处；

则问题不再是“缓冲”，而是解码/呈现时钟卡死。检查 Chromium 启动日志是否出现：

```text
media/gpu/vaapi/vaapi_wrapper.cc: vaInitialize failed
```

Tiger Lake Iris Xe（i915，`renderD128`）需要 `intel-media-driver`。验证流程：

```bash
sudo pacman -S --needed intel-media-driver libva-utils
LIBVA_DRIVER_NAME=iHD vainfo --display drm --device /dev/dri/renderD128
```

`vainfo` 应显示 Intel iHD 驱动，并列出 H.264/VP9/AV1 的 `VAEntrypointVLD`。但驱动能初始化不等于当前 Chromium + Wayland 的硬解路径一定稳定；必须重新启用硬解后再次观察 `currentTime`。

若装好驱动后硬解仍卡住，而加 `--disable-accelerated-video-decode` 后 5 秒内时间轴正常前进，则可靠修复是只禁用视频硬解（GPU 页面合成仍保留）：

```text
# ~/.config/chromium-flags.conf
--disable-accelerated-video-decode
```

重启后确认根进程参数自动包含该 flag，并分别验证 B 站和 YouTube 正片（不要只验证前贴片广告）。若 YouTube 恢复的旧标签页保持坏掉的 MSE `blob:` 状态，应新建干净标签页或刷新后重测；旧页的 `duration=null/readyState=0` 不能推翻软件解码已成功的对照结果。

## 常见误判

- 首页 `curl` 很快 ≠ 视频分片很快。
- 节点延迟低 ≠ 节点吞吐高。
- swap 已占用 ≠ 当前正在换页。
- CPU 某个 renderer 占 30% ≠ CPU 已饱和；同时看总 idle 和单核情况。
- yt-dlp/媒体 URL 返回 403、签名失效或 412 ≠ 0 B/s 网速；该探针无效，应换成站点接受的客户端头、API 或浏览器内观测。
- 隔离 profile 播放正常只能把故障缩到用户 profile；它不能替代用户前台的最终确认。
