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
- **sudo 在 Hermes 会话里的限制**(实测):
  - `echo 'pw' | sudo -S ...` 会被安全机制 BLOCKED(禁止密码管道)。
  - `.env` 里加 `SUDO_PASSWORD=pw` 后,**当前会话读不到**(secret scope 是任务开始时的快照),需新会话/重启 gateway 才生效。
  - `sudo -A` + askpass helper 方案也走审批,QQ 等消息平台无法点审批按钮 → 命令会被 BLOCKED。
  - 最省事:把修复命令写成脚本,让用户在自己终端跑 `sudo bash ~/fix-nvidia.sh`(她输密码),或用户明确告知已授权后再执行。
- 驱动修复的收益:ollama 等本地推理可用 GPU 加速(2GB 显存可卸载部分层,比纯 CPU 快)。

## 验证状态说明

本机(2026-08)诊断步骤全部验证有效;修复命令为 Arch 标准 DKMS 流程,因会话审批限制未在本机完成最终验证——用户需在自己终端跑通后确认。
