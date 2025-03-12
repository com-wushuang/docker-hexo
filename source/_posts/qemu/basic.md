---
title: qemu 基础
date: 2025-03-12 11:18:16
tags:
categories: qemu
---

## qemu 命令结构
**命令组成结构**：
```bash
#由一个个的option组成，option后接值value，每个value可以有多个属性，属性之间用等号分隔。
qemu-kvm -option1 value1[,prop=value[,...]]
```

qemu-kvm -help, 有很不错的帮助文档，常用的选项如下：
- Standard options
- Block device options
- Network options
- Character device options

## -accel

在 QEMU 中，Accelerators（加速器） 是指用于提升虚拟机性能的技术或组件。它们通过利用硬件特性或优化软件执行路径，来加速虚拟机的运行效率。QEMU 本身是一个纯软件模拟器，但通过结合加速器，可以显著提升虚拟机的性能，使其接近物理机的运行速度。

以下是 QEMU 中常见的加速器及其作用：

**1、KVM（Kernel-based Virtual Machine）**
**KVM** 是 Linux 内核中的一个模块，它允许 QEMU 直接利用硬件虚拟化技术（如 Intel VT-x 或 AMD-V）来运行虚拟机。
**工作原理**：KVM 将虚拟机作为 Linux 进程运行，并直接访问 CPU 的虚拟化扩展指令集，从而减少软件模拟的开销。
**使用场景**：适用于 Linux 主机，性能接近物理机。
**启用方式**：
```bash
qemu-system-x86_64 -enable-kvm ...
```
**2、HAXM（Intel Hardware Accelerated Execution Manager）**
**HAXM** 是 Intel 提供的硬件加速器，专为 Android 模拟器和 QEMU 设计。
**工作原理**：利用 Intel VT-x 技术加速虚拟机的执行，特别是在 Android 开发中广泛使用。
**使用场景**：适用于 Intel CPU 的 Windows 或 macOS 主机。
**启用方式**：
```bash
qemu-system-x86_64 -accel hax ...
```

**3、WHPX（Windows Hypervisor Platform）**
**WHPX** 是 Windows 提供的虚拟化平台，类似于 KVM，但专为 Windows 设计。
**工作原理**：利用 Windows Hyper-V 技术加速虚拟机的执行。
**使用场景**：适用于 Windows 主机。
**启用方式**：
```bash
qemu-system-x86_64 -accel whpx ...
```

**4、TCG（Tiny Code Generator）**
**TCG** 是 QEMU 的默认软件模拟器，用于在没有硬件虚拟化支持的环境中运行虚拟机。
**工作原理**：通过动态二进制翻译技术，将虚拟机指令翻译为主机指令并执行。
**使用场景**：适用于不支持硬件虚拟化的环境，但性能较低。
**启用方式**：
bash
qemu-system-x86_64 -accel tcg ...

**5、Xen**
**Xen** 是一个开源的虚拟化平台，QEMU 可以作为 Xen 的后端运行虚拟机。
**工作原理**：利用 Xen 的虚拟化技术加速虚拟机的执行。
**使用场景**：适用于 Xen 虚拟化环境。
**启用方式**：
```bash
qemu-system-x86_64 -accel xen ...
```

**6、Hypervisor.framework (macOS)**
**Hypervisor.framework** 是 macOS 提供的虚拟化框架，用于加速虚拟机的执行。
**工作原理**: 利用 macOS 的虚拟化技术，直接访问硬件资源。
**使用场景**：适用于 macOS 主机。
**启用方式**：
```bash
qemu-system-x86_64 -accel hvf ...
```
