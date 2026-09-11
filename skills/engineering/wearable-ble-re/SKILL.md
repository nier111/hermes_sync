---
name: wearable-ble-re
description: "Use when sniffing smart-band BLE/RFCOMM traffic via Android."
version: 1.0.0
author: Aoi
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [ble, rfcomm, bluetooth, reverse-engineering, android, wearable, smartband]
---

# 智能手环 BLE/RFCOMM 逆向（Android HCI 抓包）

用于“截取并理解”小米手环等可穿戴与 App 之间的蓝牙通信。

## 1. 开启抓包（vivo 示例）

1. 开发者选项 → 启用蓝牙 HCI 信息收集日志
2. 重启蓝牙：`adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable`
3. 验证：
   ```bash
   adb shell getprop persist.sys.bluetooth.btsnooplogmode   # full
   adb shell dumpsys bluetooth_manager | grep -i snoop       # sSnoopLogSettingAtEnable = FULL
   ```
4. 单变量操作一次（如“查找设备”），随后立即：
   ```bash
   adb bugreport <name>.zip
   ```

## 2. 提取并解码

```bash
unzip -l <name>.zip | grep btsnoop          # FS/data/misc/bluetooth/logs/bt_hci_*.cfa
# .cfa 实际是标准 btsnoop
btmon -r bt_hci_*.cfa -P -T -C 160 > dump.txt
```

不要按旧款手环假设是 BLE GATT：小米手环10 实际走 **BR/EDR + RFCOMM (SCN5/DLCI10)**，链路加密，应用帧封装在 RFCOMM UIH 内。

## 3. 小米手环10 SPP v2 分层（已验证）

```text
L1: A5 A5 | type/frx | seq | len_le16 | crc_le16 | L1 payload
L2: channel | opcode | L2 payload
ACK: A5 A5 01 <seq> 00 00 00 00
CRC = CRC-16/MODBUS (0xA001) init 0x0000，覆盖完整 L1 payload
```

protobuf 业务帧的 L2 头为 `01 02`：channel 1 + encrypted-write opcode 2；只有其后的 protobuf 被加密。旧 SPP v1 使用 `BA DC FE`，不要与 v2 混用。

SPP v2 业务加密为 `AES/CTR/NoPadding(key=AppKey, IV=AppKey)`。WearAuthV2 用绑定 token 和 `AppRandom || DeviceRandom` 做 HKDF-SHA256，info=`miwear-auth`，输出的 `[16:32]` 是 AppKey。该链已用真实 start/stop 帧端到端解密验证。

解析/构造、HKDF、批量解密代码见项目 `miband10_frames.py` 和 `analyze_capture.py`。

## 4. 业务→字节定位

- 下载 APK：`adb pull $(adb shell pm path <pkg> | sed 's/package://') base.apk`
- 单 dex 反编译（避免整包内存爆）：
  ```bash
  unzip -o base.apk 'classes*.dex' -d dex/
  jadx --no-res --show-bad-code -d out classesN.dex
  ```
- 反混淆后类名通常是 `defpackage/*`。跨 dex 找类归属：
  直接解析 dex class_defs 的 type descriptor，比搜字符串准。
- 常见模式：业务层把 `{cmd_type, sub_cmd, nested}` 组成 protobuf（nano），再经会话层加密后经 A5A5 帧发出。
- “查找设备”明文：
  ```text
  start: 08 02 10 12 22 02 28 00
  stop : 08 02 10 12 22 02 28 01
  ```

## Pitfalls

- **按型号查实际传输**：先看 btmon 里是 LE-ACL 还是 BR-ACL/RFCOMM，再决定解析思路。
- **别把 RFCOMM 末尾的 FCS 字节算进应用帧**：btmon 每行末尾一个字节是 RFCOMM FCS。
- **ACL 大数据包带 `[n/m]` 分片**：需要按 HCI handle 重组，直接按行 grep 会漏。
- **不要把“发送相同重复帧”误判为完整状态机**：停止可能是独立命令，需源码对照。
- **只读/静态阶段不发送任何字节**；改帧之前先记录配对与恢复路径。
- vivo shell 直接 `setprop persist.*` 会被拒；必须通过系统开发者开关。
- 手机开启 HCI 日志后需重启蓝牙才生效，新文件按时间戳命名，取最新一份。

## 参考项目

- `atc1441/MiBand10-BES2700iMP-BEST1503-Hacking`：完整固件/UART 刷写与 Doom
- 本项目 README：`~/projects/miband10-re/README.md`
