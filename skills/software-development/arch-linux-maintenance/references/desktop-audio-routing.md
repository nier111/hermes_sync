# Per-application audio routing and game-stutter triage

Use for “one app has no sound”, USB DAC routing, or audio glitches that coincide with frame drops.

## Route the live stream, not only the default device

Changing the default sink does not guarantee already-running streams move.

```bash
pactl get-default-sink
pactl list short sinks
pactl list sink-inputs
```

In `pactl list sink-inputs`, identify the stream by `application.name`, then note its `Sink Input #N` and current `Sink:`. Move it:

```bash
pactl move-sink-input N exact_sink_name
pactl set-default-sink exact_sink_name
```

Verify that the stream’s `Sink:` changed and the target sink is `RUNNING`. GUI equivalent: `pavucontrol` → Playback → output-device dropdown for that application.

## USB DAC verification

A standard USB Audio Class DAC needs no vendor driver on Linux. Check all three layers:

```bash
lsusb
lsusb -t                 # expect Driver=snd-usb-audio
pactl list short cards
pactl list short sinks
```

A newly enumerated USB sink with the product string proves digital USB audio is available. Passive USB-C-to-3.5mm analog adapters are a separate case and may not work; active adapters/DACs are the reliable path.

## When audio glitches coincide with frame drops

Do not blame the DAC first. Capture synchronized evidence:

```bash
uptime
free -h
vmstat 1 5
ps -eo pid,ppid,%cpu,%mem,rss,stat,comm,args --sort=-%cpu
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,pstate --format=csv,noheader
journalctl --user --since '15 minutes ago' --no-pager
pactl info
```

Interpretation:

- `q overrun`, `xrun`, or underrun messages during high load indicate the audio server was starved.
- GPU near 100% means scene/render bottleneck even if an earlier sample was lower; take more than one sample.
- High load average plus runnable tasks indicates CPU scheduling pressure.
- Swap occupancy alone is not proof of active thrashing; use `vmstat` `si/so`.
- `ps %CPU` is averaged over process lifetime. Use `top`, `pidstat`, or repeated samples for instantaneous load.
- Verify the game is on the intended GPU with `nvidia-smi pmon`; do not infer from desktop `glxinfo` alone.
- Inspect `pactl info` before calling the stack PipeWire: a machine may run WirePlumber for some roles while `Server Name` is still PulseAudio.

## Browser video stalls caused by a broken audio clock

Chromium/HTML5 video can appear to “buffer forever” even when the media bytes are already downloaded if the selected audio sink is suspended or its ALSA queue is broken. Strong evidence is:

- the page and media CDN load normally;
- the `<video>` element reports `readyState=4`, `paused=false`, and buffered data ahead;
- `currentTime` does not advance with wall time;
- unplugging/replugging a USB DAC sometimes restores both sound and video;
- Pulse logs contain `Failed to create sink input: sink is suspended`, `Failed to push data into queue`, or `snd_pcm_avail() returned 0`.

Check that Chromium sink inputs point to the intended sink and that the sink becomes `RUNNING` during playback. As a low-risk causal test, restart the active audio server and verify both video and sound recover before changing network or browser settings.

### Avoid PulseAudio + WirePlumber competing for ALSA

A broken Arch configuration can have standalone `pulseaudio` running while `pipewire`, `wireplumber`, `pipewire-alsa`, and `pipewire-jack` are also installed and active. Evidence includes WirePlumber/SPA errors such as `playback open failed: Device or resource busy`, while `pactl info` still says plain `Server Name: pulseaudio`.

Prefer one coherent PipeWire stack:

```bash
sudo pacman -S pipewire-pulse
systemctl --user daemon-reload
systemctl --user restart pipewire.service wireplumber.service
systemctl --user enable --now pipewire-pulse.socket
systemctl --user restart pipewire-pulse.service
```

`pipewire-pulse` conflicts with standalone `pulseaudio`; handle pacman's conflict-removal confirmation explicitly rather than removing packages with `-Rdd`. After migration verify:

- `pactl info` says `PulseAudio (on PipeWire ...)`;
- the USB DAC is the default sink;
- the DAC sink is `RUNNING` during playback;
- Chromium streams are attached to it;
- Bilibili and YouTube both play continuously with stable audio.

A one-time xdg-desktop-portal PipeWire disconnect during the service restart is expected; continuing errors are not.

## Low-risk first actions

- Close monitoring GUIs only after measuring them; `pavucontrol` itself can occasionally consume noticeable CPU.
- On AC power, test `powerprofilesctl set performance`, then re-measure. Restore with `powerprofilesctl set balanced` afterward.
- Prefer in-game VSync/FPS caps and lower resolution/quality before audio-server surgery when GPU or CPU saturation is proven.
- Increase per-game audio buffering only after confirming overruns; document the latency trade-off and verify the result rather than assuming it helped.