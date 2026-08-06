---
name: arch-nvidia-dkms-fix
description: "Use when Arch kernel update breaks nvidia-smi. DKMS rebuild."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [arch, nvidia, dkms, kernel, driver]
---

# Arch Linux 内核更新后 NVIDIA 驱动失效修复

症状:`nvidia-smi` 报 "NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver"、`lsmod | grep nvidia` 为空。典型场景:Arch 频繁更新内核,新内核下 DKMS 模块没构建。

## 诊断(2026-08 在本机验证有效)

```bash
uname -r                                    # 当前内核
pacman -Q nvidia nvidia-open-dkms nvidia-utils   # 驱动包(注意 nvidia-open-dkms)
lsmod | grep nvidia                         # 空 = 模块未加载
lspci | grep -i nvidia                      # 确认硬件(如 GeForce MX450)
dkms status                                 # 显示模块为哪个内核构建的
ls /usr/lib/modules/$(uname -r)/kernel/drivers/video/ | grep nvidia   # 缺 = 没构建
pacman -Q linux-lts linux-lts-headers       # headers 缺失是常见根因
```

**常见根因**:内核更新(如进入 `6.18.x-lts`)后,DKMS 只为主内核构建过模块(`dkms status` 里没有当前内核);通常因为 `linux-lts-headers` 没装,DKMS 无法编译。

## 修复(标准 DKMS 流程)

```bash
# 1. 装与当前内核匹配的头文件
sudo pacman -S --needed linux-lts-headers
# 2. 为所有已装内核重建模块(编译需几分钟)
sudo dkms autoinstall
# 3. 加载模块
sudo modprobe nvidia && sudo modprobe nvidia_modeset && sudo modprobe nvidia_uvm
# 4. 验证
nvidia-smi
```

可打包成脚本交给用户执行:装 headers → dkms autoinstall → modprobe → nvidia-smi 验证,每步 echo 进度。

## Pitfalls

- **MX450(TU117M,Turing)用 `nvidia-open-dkms`**(open 内核模块支持 Turing+);老卡(≤Pascal)要用闭源 `nvidia-dkms`。
- **模块编译完但 modprobe 报 "Module not found" → 先 `sudo depmod -a`**(2026-08 实机踩坑):pacman 的 `70-dkms-install.hook` 用 `--no-depmod` 编译,依赖事务末尾的 `60-depmod.hook` 建索引;若 pacman 前台命令超时被中断,depmod 没跑,`/lib/modules/$(uname -r)/updates/dkms/` 里有 .ko 但 modprobe 找不到。修:`sudo depmod -a && sudo modprobe nvidia ...`。
- **pacman 前台命令超时被杀 → `/var/lib/pacman/db.lck` 残留**:先确认 `ps aux | grep pacman` 无进程,再 `sudo rm /var/lib/pacman/db.lck` 重试。大包(如 ollama-cuda 几百 MB,镜像慢)用 `background=true` + `notify_on_complete=true` 跑,别用前台 timeout。
- **后台 terminal 的 sudo 没有凭据注入**:后台命令里必须显式 `SUDO_ASKPASS=/home/sato/.hermes/askpass.sh sudo -A pacman ...`,否则报 "a terminal is required to read the password" 且 exit 1(日志里 EXIT=1 而外层 exit 0 是假成功——检查日志尾部的 EXIT= 行)。
- **ollama 加速(2026-08 实测)**:Arch 的 `ollama` 包是纯 CPU 版(依赖仅 libgcc/libstdc++/glibc),GPU 需另装 `ollama-cuda`(`pacman -S ollama-cuda`,与 ollama 共存);装后 `systemctl restart ollama`,日志出现 `inference compute id=cpu` 以外、llama-server 以 Compute 模式占显存即生效。**MX450 2GB 显存对 3B VLM 只能部分 offload(实测仅 ~150MB),速度与纯 CPU 相当——别承诺"会快很多"**;真正提速要 8G+ 显存。
- **sudo 在 Hermes 会话里的限制**(实测):
  - `echo 'pw' | sudo -S ...` 会被安全机制 BLOCKED(禁止密码管道)。
  - `.env` 里加 `SUDO_PASSWORD=pw` 后,**当前会话读不到**(secret scope 是任务开始时的快照),需新会话/重启 gateway 才生效。
  - 前台命令用 `SUDO_ASKPASS=/home/sato/.hermes/askpass.sh sudo -A ...` 有效(askpass 脚本读 ~/.hermes/.env);若 askpass 报 Permission denied,先 `chmod +x ~/.hermes/askpass.sh`。
  - 最省事:把修复命令写成脚本,让用户在自己终端跑 `sudo bash ~/fix-nvidia.sh`(她输密码),或用户明确告知已授权后再执行。
- 驱动修复的收益:ollama 等本地推理可用 GPU 加速(2GB 显存可卸载部分层,比纯 CPU 快——但见上,3B VLM 提升有限)。

## 验证状态说明

本机(2026-08-06)已完整跑通全流程:装 linux-lts-headers → dkms 编译(lts 内核,耗时数分钟,pacman hook 里跑,用轮询等)→ `depmod -a` → modprobe 三件套 → `nvidia-smi` 正常输出(610.43.03,CUDA UMD 13.3,MX450 识别)。
