---
title:  openstack configuration drive 详解
date: 2023-09-25 15:18:17
tags:
categories: OpenStack
---
### 概述
- openstack 可以用 configuration  drive 来存储元数据
- configuration driver 在云主机创建时被附加到云主机上，如下：
```xml
  <devices>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw' cache='none'/>
      <source file='/var/lib/nova/instances/158db6f9-73b6-41cc-bd21-3cda02c4b6e9/disk.config'/>
      <target dev='hda' bus='ide'/>
      <readonly/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
```
- 在虚机内部，通过 mount 这个 driver 你就能够用读取文件的方式，读取其中存储的元数据
- cloud-init 就是通过读取这些元数据来进行云主机的定制化，比如：设置密码、安装软件、配置网络

### 依赖和前置条件
想要使用 configuration drive 需要满足如下条件
**计算节点**
- 支持 configuration drive 虚拟化软件：libvirt, XenServer, Hyper-V, VMware
- 计算节点上需要安装 genisoimage 软件，genisoimage 命令来自英文词组"generate iso image" 的缩写，其功能是用于创建 iso 镜像文件
- 因此，当你创建虚机时，libvirt 调用 genisoimage 制作一个 iso 格式只读光盘，并附加在虚机上

**镜像**
- 镜像内置了 cloud-init 
- 虚机操作系统必须支持可挂载 ISO 9660 或 VFAT 格式的文件系统
- 因此，在虚机启动的时候，cloud-init 通过挂载后以读取文件的方式获得元数据，并根据元数据进行主机定制化

### 开启 configuration driver 功能
1、在创建虚机时，使用 --config-drive true 参数
```
nova  boot chengjun --flavor s2.large.1 --image 8b83cd0c-9313-49d1-91dc-17151ba9aef6 --nic net-id=a9a138e1-2b60-4193-83b9-98e06be8260e  --user-data /home/userdata.cfg --config-drive true
```
2、计算节点配置文件，强制所有虚机使用 configuration driver
```
force_config_drive = true
```
3、在虚机中读取（前提虚机操作系统支持通过label访问disk）
```bash
mkdir -p /mnt/config
mount /dev/disk/by-label/config-2 /mnt/config
```
4、如果虚机操作系统不支持通过label访问disk
- 通过 blkid 找到 configuration drive 对应的块设备id
```bash
blkid -t LABEL="config-2" -odevice
```
- 找到以后（比如是/dev/vdb），在继续挂载操作
```bash
mkdir -p /mnt/config
mount /dev/vdb /mnt/config
```
### configuration drive 格式
1、默认的 configuration drive 格式为 ISO 9660 文件系统,显示指定
```
config_drive_format=iso9660
```
2、由于历史遗留原因，configuration drive 也支持 VFAT 格式
```
config_drive_format=vfat
```


###  一些源码
- nova\virt\configdrive.py
```python
    def make_drive(self, path):
        """Make the config drive.

        :param path: the path to place the config drive image at

        :raises ProcessExecuteError if a helper process has failed.
        """
        with utils.tempdir() as tmpdir:
            self._write_md_files(tmpdir)

            if CONF.config_drive_format == 'iso9660':
                self._make_iso9660(path, tmpdir)
            elif CONF.config_drive_format == 'vfat':
                self._make_vfat(path, tmpdir)
            else:
                raise exception.ConfigDriveUnknownFormat(
                    format=CONF.config_drive_format)
```
- 调用 geniosimage 命令创建 config drive
- 根据 config_drive_format 配置的不同，调用不同的方法