---
title: kvm 安装 windows
date: 2023-04-25 11:18:16
tags:
categories: kvm
---

## 创建 windows 虚拟机
```shell
virt-install \
  --network bridge=virbr0,model=virtio \
  --name win10 \
  --ram=2048 \
  --vcpus=1 \
  --os-type=windows --os-variant=win10 \
  --disk path=/var/lib/libvirt/images/win10.qcow2,format=qcow2,bus=virtio,cache=none,size=32 \
  --graphics vnc,listen=0.0.0.0,port=9999 --noautoconsole \
  --cdrom=/var/lib/libvirt/images/Win10_1903_V2_English_x64.iso
  ```

## 挂载 virtio-win 驱动
- 由于 `virt-install` 不直接支持多个 `cdrom` ，所以在上述安装启动之后，使用 `virsh edit` 增加第二个 `cdrom` 设备( `cdrom` 不支持热插拔，所以需要重启虚拟机)，以便在 `Windows` 安装过程中提供 `virtio` 驱动。
- 参考的 xml 如下：
```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/en_windows_10_enterprise_version_1607_updated_jul_2016_x86_dvd_9060097.iso'/>
  <target dev='sda' bus='sata'/>
  <readonly/>
  <address type='drive' controller='0' bus='0' target='0' unit='0'/>
</disk>
```
- 新增的 xml 如下：
```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/virtio-win.iso'/>
  <target dev='sdb' bus='sata'/>
  <readonly/>
  <address type='drive' controller='0' bus='0' target='0' unit='1'/>
</disk>
```
## 更改启动顺序
由于默认虚拟机的XML指定启动设备只有硬盘，所以再次使用 `virsh start win10` 将不能从光盘启动。
- 需要在 `virsh edit win10` 中将:
```xml
<os>
  <type arch='x86_64' machine='pc-q35-4.1'>hvm</type>
  <boot dev='hd'/>
</os>
```
- 修改为：
```xml
<os>
  <type arch='x86_64' machine='pc-q35-4.1'>hvm</type>
  <boot dev='cdrom'/>
  <boot dev='hd'/>
</os>
```
参考：[Booting from a cdrom in a kvm guest using libvirt](https://mycfg.net/articles/booting-from-a-cdrom-in-a-kvm-guest-with-libvirt.html)

## vnc 连接安装windows
- 在安装过程中，最初无法识别的 `virtio` 设备。注意在提示驱动加载时直接点ok， `windows` 安装程序会自动搜索到可能的驱动，你只需要选择 `win10` 驱动就可以了。
- 安装完毕在重启 `windows` 操作系统之前，请务必重新 `virsh edit win10` 去除优先从 `cdrom` 启动设置。
![windows_load_virtio_drivers](https://raw.githubusercontent.com/com-wushuang/pics/main/windows_load_virtio_drivers.png)

## 更新驱动程序
- 安装完操 `Windows` 之后，需要注意这个虚拟机的硬件，包括虚拟网卡，虚拟串口等设备都是 `virtio` 类型的，默认的 `Windows` 系统都没有驱动，所以还需要再 【设备管理器】中更新驱动
![update_virtio_drivers](https://raw.githubusercontent.com/com-wushuang/pics/main/update_virtio_drivers.png)

