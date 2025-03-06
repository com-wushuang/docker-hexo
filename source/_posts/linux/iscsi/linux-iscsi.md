---
title: Linux上配置使用iSCSI
date: 2025-03-06 09:31:18
index_img: /img/linux/iscsi/iscsi_data_wrap.png
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
```

### target认证
#### 基于IP认证
可以将一个IP地址绑定到一个target上，这样只有这个IP地址的客户端才能连接到这个target。
```shell
tgtadm --lld iscsi --mode target --op bind --tid 1 --initiator-address 192.168.234.0/24 # 绑定了允许连接的initiator的ip地址
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
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 42950 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/sdb
            Backing store flags: 
    Account information:
    ACL information: # 可以看到绑定的IP地址
        192.168.234.0/24
```

#### 基于CHAP认证
基于IP的认证比较粗糙，对于安全性要求高的环境来说，使用CHAP认证更好。

# initiator 端
## 安装
- 安装软件
```shell
yum -y install iscsi-initiator-utils
```
- 查看安装文件：通过该命令我们能够了解安装了那些二进制文件、程序的配置文件路径等。
```shell
rpm -ql iscsi-initiator-utils

/etc/iscsi
/etc/iscsi/ifaces
/etc/iscsi/ifaces/iface.example
/etc/iscsi/initiatorname.iscsi
/etc/iscsi/iscsid.conf
/etc/iscsi/isns
/etc/iscsi/nodes
/etc/iscsi/send_targets
/etc/iscsi/slp
/etc/iscsi/static
/etc/logrotate.d/iscsiuiolog
/usr/lib/systemd/system/iscsi.service
/usr/lib/systemd/system/iscsid.service
/usr/lib/systemd/system/iscsid.socket
/usr/lib/systemd/system/iscsiuio.service
/usr/lib/systemd/system/iscsiuio.socket
/usr/lib64/libopeniscsiusr.so.0
/usr/lib64/libopeniscsiusr.so.0.2.0
/usr/sbin/iscsi-gen-initiatorname
/usr/sbin/iscsi-iname
/usr/sbin/iscsi_discovery
/usr/sbin/iscsi_fw_login
/usr/sbin/iscsi_offload
/usr/sbin/iscsiadm
/usr/sbin/iscsid
/usr/sbin/iscsistart
/usr/sbin/iscsiuio
/usr/share/doc/open-iscsi
/usr/share/doc/open-iscsi/COPYING
/usr/share/doc/open-iscsi/README
/var/lock/iscsi
/var/lock/iscsi/lock
```

## 启动守护进程
```shell
systemctl start iscsid
systemctl enable iscsid
```

## 和target交互
### iscsi-iname命令
- initiator也有一个唯一标识，initiator在连接target的时候，会读取/etc/iscsi/initiatorname.iscsi中的内容作为自己的iname。
```shell
cat /etc/iscsi/initiatorname.iscsi 
InitiatorName=iqn.2012-01.com.openeuler:e24f82c5d9d
```
- 若要自指定iname，可以手动修改该文件。也可以使用iscsi-iname工具来生成iname并保存到该文件
```shell
iscsi-iname
iqn.2012-01.com.openeuler:5a804fa64f8e
```

### iscsiadm命令
scsiadm也是一个模式化的命令，使用-m指定mode。mode有:discovery、node、session、iface。一般就用前两个mode。

- discovery：发现target。
- node：管理跟某target的关联关系。
- session：会话管理。
- iface：接口管理。

#### discovery
```shell
iscsiadm -m discovery -d debug_level -t type -p ip:port -I ifaceName # 格式
iscsiadm -m discovery -t st -p 192.168.234.131:3260 # 实例

-d：输出调试信息，级别从0-8。出现错误的时候用来判断错误来源是很有用处的，可以使用级别2。
-I：指定发现target时通信接口。
-t type：有三种type(sendtargets,SLP,iSNS)，一般只会用到sendtargets，可以简写为st。
-p IP:PORT：指定要发现target的IP和端口，不指定端口时使用默认的3260。
```

#### node
```shell
iscsiadm -m node -d debug_level -T targetname -p ip:port -I ifaceN -l | -u -o operation # 格式
iscsiadm -m node -T iqn.2019-01.com.aliyun:28329176 -p 192.168.234.131:3260 -l # 实例

-d：指定debug级别，有0-8个级别。
-L和-U：分别是登录和登出target，可以指定ALL表示所有发现的target，或者manual指定。
-l和-u：分别是登录和登出某一个target。
-T：用于-l或-u时指定要登录和登出的targetname。
-o：对discoverydb做某些操作，可用的操作有new/delete/update/show，一般只会用到delete和show。
```

#### 使用
1.发现，登录完成后，在initiator端可以就可以看到硬盘了
```shell
lsblk
```
2.对于云计算场景，计算节点此时就能看到硬盘了，然后qemu-kvm就像使用本地盘一样使用该硬盘。
```xml
<disk type='block' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source dev='/dev/disk/by-path/ip-10.0.0.2:3260-iscsi-iqn.2010-10.org.openstack:volume-2ed1b04c-b34f-437d-9aa3-3feeb683d063-lun-0'/>
      <target dev='vdb' bus='virtio'/>
      <serial>2ed1b04c-b34f-437d-9aa3-3feeb683d063</serial>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
</disk>
```

# CHAP认证
- **initiator authentication认证**：在initiator尝试连接到一个target的时候，initator需要提供一个用户名和密码给target被target进行认证。也就是说initiator需要被target认证，它向target端提供的账号和密码是target端指定的。

- **target authentication认证**：在initiator尝试连接到一个target的时候，target有时也需要被initiator认证，以确保该target是合法而非伪装的target，这就要求target提供一个用户名和密码给initiator被initiator进行认证。

- initiator authentication可以单独存在，它可以在没有target authentication的情况下应用，这时候的CHAP认证就是单向认证；但target authentication只有在initiator authentication的基础上才能进行。也就是说target认证和initiator认证必须同时存在才可以。即双向CHAP认证。


##### CHAP单向认证
1.首先确保target的ACL是允许initiator进行discovery的
```shell
    Account information:
    ACL information:
        192.168.234.0/24
```
2.在target端创建initiator authentication所需的账号和密码
```shell
tgtadm --lld iscsi --mode account --op new --user aliyun --password 123456
```
3.绑定到target上
```shell
tgtadm -L iscsi -m account -o bind -t 1 --user aliyun
```
4.查看绑定情况
```shell
    Account information:
        aliyun
    ACL information:
        192.168.234.0/24
```
5.initiator连接target，需要提供账号和密码,如果未提供,则认证失败
```shell
# 发现
iscsiadm -m discovery -t st -p 192.168.234.131:3260
192.168.234.131:3260,1 iqn.2019-01.com.aliyun:28329176

# 登录失败
iscsiadm -m node -T iqn.2019-01.com.aliyun:28329176 -p 192.168.234.131:3260 -l
Logging in to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260]
iscsiadm: Could not login to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260].
iscsiadm: initiator reported error (24 - iSCSI login failed due to authorization failure)
iscsiadm: Could not log into all portals
```

6.配置密码,认证成功
```shell
vim /etc/iscsi/iscsid.conf
node.session.auth.authmethod = CHAP
node.session.auth.username = aliyun
node.session.auth.password = 123456

# 发现
iscsiadm -m discovery -t st -p 192.168.234.131:3260
192.168.234.131:3260,1 iqn.2019-01.com.aliyun:28329176

# 登录成功
iscsiadm -m node -T iqn.2019-01.com.aliyun:28329176 -p 192.168.234.131:3260 -l
Logging in to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260]
Login to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260] successful.
```

##### CHAP双向认证
1.要双向认证，那么target端还需要创建一个outgoing账号和密码,注意下面的--outgoing选项
```shell
tgtadm -L iscsi -m account -o new --user outgoing_aliyun --password 123456
```
2.绑定到target上，注意下面的--outgoing选项
```shell
tgtadm -L iscsi -m account -o bind -t 1 --user outgoing_aliyun --outgoing
```
3.查看绑定
```shell
    Account information:
        aliyun
        outgoing_aliyun (outgoing) # 两个账号
    ACL information:
        192.168.234.0/24
```
4.initiator连接target，需要提供账号和密码,如果未提供,则认证失败
```shell
# 发现
iscsiadm -m discovery -t st -p 192.168.234.131:3260
192.168.234.131:3260,1 iqn.2019-01.com.aliyun:28329176

# 登录失败
iscsiadm -m node -T iqn.2019-01.com.aliyun:28329176 -p 192.168.234.131:3260 -l
Logging in to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260]
iscsiadm: Could not login to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260].
iscsiadm: initiator reported error (19 - encountered non-retryable iSCSI login failure)
iscsiadm: Could not log into all portals
```
5.配置密码,认证成功
```shell
vim /etc/iscsi/iscsid.conf
node.session.auth.authmethod = CHAP
node.session.auth.username = aliyun
node.session.auth.password = 123456
node.session.auth.username_in = outgoing_aliyun

# 发现
iscsiadm -m discovery -t st -p 192.168.234.131:3260
192.168.234.131:3260,1 iqn.2019-01.com.aliyun:28329176

# 登录成功
iscsiadm -m node -T iqn.2019-01.com.aliyun:28329176 -p 192.168.234.131:3260 -l
Logging in to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260]
Login to [iface: default, target: iqn.2019-01.com.aliyun:28329176, portal: 192.168.234.131,3260] successful.
```