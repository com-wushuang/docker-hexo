---
title: Linux上配置使用iSCSI
date: 2025-03-06 09:31:18
tags:
---

# 简介
## scsi 和 iscsi
- scsi是一种串行接口，用于连接硬盘、光驱、U盘等设备。
- iscsi是一种网络协议，它是由IBM公司研发：能够让SCSI接口与以太网技术相结合，使用iSCSI协议基于以太网传送SCSI命令与数据，克服了SCSI需要直接连接存储设备的局限性，使得可以跨越不同的服务器共享存储设备。

## iSCSI数据封装
![数据封装](/img/linux/iscsi/iscsi_data_wrap.png)

### 软件实现封装
- initiator向target发起scsi命令后，在数据报文从里向外逐层封装SCSI协议报文、iSCSI协议报文、tcp头、ip头。
- 封装是需要消耗CPU资源的，如果完全以软件方式来实现iscsi，那么所有的封装过程都由操作系统来完成。在很繁忙的服务器上，这样的资源消耗可能不太能接受，但好在它是完全免费的。

### 硬件实现封装
- 除了软件方式实现，还有硬件方式的initiator(TOE卡和HBA卡)，通过硬件方式实现iSCSI。由于它们有控制芯片，可以帮助或者完全替代操作系统对协议报文的封装。
- TOE卡，操作系统首先封装SCSI和iSCSI协议报文，而TCP/IP头则交由TOE内的芯片来封装，这样就能减少一部分系统资源消耗。
- HBA卡，操作系统只需封装SCSI，剩余的iSCSI协议报文还有TCP/IP头由HBA芯片负责封装。

![硬件封装](/img/linux/iscsi/digital_data_wrap.png)

## 工作流
![工作流](/img/linux/iscsi/use_workflow.png)

# target端
- target端是工作在套接字上的，监听端口默认是3260，且使用的是tcp连接。
- 对客户端有身份认证的需要，有两种认证方式：基于IP认证，基于CHAP认证(双向认证)。

## 安装
- 安装软件
```shell
yum -y install scsi-target-utils
```
- 查看安装文件：通过该命令我们能够了解安装了那些二进制文件、程序的配置文件路径等。
```shell
rpm -ql scsi-target-utils

/etc/sysconfig/tgtd
/etc/tgt
/etc/tgt/conf.d
/etc/tgt/conf.d/sample.conf
/etc/tgt/targets.conf
/etc/tgt/tgtd.conf
/usr/lib/systemd/system/tgtd.service
/usr/sbin/tgt-admin # 管理target的命令
/usr/sbin/tgt-setup
/usr/sbin/tgt-setup-lun
/usr/sbin/tgtadm # 管理target的命令
/usr/sbin/tgtimg
/usr/sbin/tgtd # 启动target的守护进程
/usr/share/doc/scsi-target-utils
/usr/sbin/tgtimg
/usr/share/doc/scsi-target-utils
/usr/share/doc/scsi-target-utils/README
/usr/share/doc/scsi-target-utils/README.iscsi
/usr/share/doc/scsi-target-utils/README.iser
/usr/share/doc/scsi-target-utils/README.lu_configuration
/usr/share/doc/scsi-target-utils/README.mmc
/usr/share/doc/scsi-target-utils/README.ssc
```
## 启动守护进程
```
systemctl start tgtd
systemctl enable tgtd
```

## 管理target
### tgtadm命令
- tgtadm是一个高度模式化的命令。
- 有三个模式:target、logicalunit、account。
- 指定模式时使用--mode选项。
- 再使用--op来指定对应模式下的选项。
- 另外，使用-lld指定driver，有两种driver：iscsi和iser，基本都会使用iscsi。
- 抛去driver部分，target、logicalunit和account这3种模式下的操作方式简化后如下：
![tgtadm命令](/img/linux/iscsi/command_help.png)

### 创建target
创建target时，要指定targetname，格式为：iqn.YYYY-mm.<reversed domain name>[:identifier]
- iqn是iscsi qualified name的缩写，就像fqdn一样。
- YYYY-mm描述的是此target是何年何月创建的，如2016-06。
- <reversed domain name>是域名的反写，起到了唯一性的作用，如com.aliyun。
- identifier是可选的，是为了知道此target相关信息而设的描述性选项，如指明此target用到了哪些硬盘。
-- 
```shell
# 创建target时，tid不能是0，因为0是被系统保留的
tgtadm --lld iscsi --mode target --op new --tid 1 --targetname iqn.2019-01.com.aliyun:28329176
```
### 查看target
```shell
tgtadm --lld iscsi --mode target --op show

Target 1: iqn.2019-01.com.aliyun:28329176
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0 # 创建完target后自动就创建lun 0
            Type: controller # 是控制器
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null # 因为是控制lun，所以没有backing store
            Backing store path: None
            Backing store flags: 
    Account information:
    ACL information:
```

### 新增lun
```shell
# 新增lun时，lun不能是0，因为0是被系统保留的,并作为控制器使用
# --backing-store 指定lun的backing store,指向一个主机上的disk设备
tgtadm --lld iscsi --mode logicalunit --op new --tid 1 --lun 1 --backing-store /dev/sdb
```
### 查看lun
```shell
tgtadm -L iscsi -m target -o show

Target 1: iqn.2019-01.com.aliyun:28329176
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 1
            Type: disk # 是disk，不再是controller
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 42950 MB, Block size: 512 # 大小信息
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/sdb # 指向的是一个disk设备
            Backing store flags: 
    Account information:
    ACL information:
