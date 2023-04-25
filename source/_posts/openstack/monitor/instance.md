# 云主机监控

## 基于 libvirt
- `libvirt` 是使用最广泛的 `KVM` 管理工具（应用程序接口）就是 `libvirt` `。Libvirt` 提供了操作 `KVM` 的原生层接口，可以实现对虚拟机的基本管理操作。
- `Libvirt` 库用 `C` 实现，且包含对 `python` 的直接支持。
- `Libvirt-python` 就是基于 `libvirt API` 的 `python` 语言绑定工具包，通过该包可以实现对 `VM` 日常管理和监控数据的获取。
- `Libvirt-python` 的接口文档：https://libvirt-python.readthedocs.io/monitoring-performance/


## 基于 QGA
`QGA` 是一个运行在虚拟机内部的普通应用程序，其目的是实现一种宿主机和虚拟机进行交互的方式，这种方式不依赖于网络，而是依赖于 `virtio-serial` 或者 `isa-serial` ，而 `QEMU` 则提供了串口设备的模拟及数据交换的通道，最终呈现出来的是一个串口设备（虚拟机内部）和一个 `unix socket` 文件（宿主机上）。

 

`QGA` 通过读写串口设备与宿主机上的 `socket` 通道进行交互，宿主机上可以使用普通的 `unix socket` 读写方式对 `socket` 文件进行读写，最终实现与 `QGA` 的交互，交互的协议与 `QMP` （`QEMU Monitor Protocol`）相同（简单来说就是使用 `JSON` 格式进行数据交换），串口设备的速率通常都较低，所以比较适合小数据量的交换。

QMP：http://wiki.qemu.org/QMP