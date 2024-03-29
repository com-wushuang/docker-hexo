---
title:  cloud-init 详解
date: 2023-09-25 15:18:17
tags:
categories: OpenStack
---
## 简介
**一、概述**
cloud-init 是 linux 的一个工具，当系统启动时，cloud-init 可从 nova metadata 服务或者 config drive 中获取 metadata，完成包括但不限于下面的定制化工作：

- 设置 default locale
- 设置 hostname
- 添加 ssh keys到 .ssh/authorized_keys
- 设置用户密码
- 配置网络
- 安装软件包

**二、阶段**
为了实现 instance 定制工作，cloud-init 会按 4 个阶段执行任务：
- local
- init
- config
- final

cloud-init 安装时会将这 4 个阶段执行的任务以服务的形式注册到系统中，比如在 systemd 的环境下，我们能够看到这4个阶段分别对应的服务：
- local - cloud-init-local.service
- init - cloud-init.service
- config - cloud-config.service
- final - cloud-final.service

cloud-init 的执行过程被详细记录在：
- /var/log/cloud-init.log 

cloud-init 的配置文件：
- /etc/cloud/cloud.cfg

**三、数据源**

- cloud-init 是一种初始化配置工具，它根据数据源中的数据配置计算机。目前内置的数据源有：OpenStack、ConfigDrive、Amazon EC2、Azure等等
- cloud-init 在虚机启动会根据配置的数据源列表一个一个查找实例数据，首个能够找到实例数据的数据源将成为这次启动的数据源
- 如果指定了 OpenStack 数据源，那么实例数据将均通过HTTP API请求获取
- 如果是 ConfigDrive 数据源，那么实例数据将均通过文件获取，cloud-init会搜索标记有CONFIG-2标签的分区，随后将该分区挂载至临时目录中，并读取其中包含实例数据的文件
- 根据用途，可以将实例数据划分为如下三类：
    - nova metadata
    - user data
    - vendor data

**User data**
- 用户在创建虚拟机时指定的一组数据，一般是脚本文件，cloud-init 会把读取这些脚本并运行
- openstack server create 命令传入 user data
```
openstack server create --user-data mydata.file
```
- mydata.file 文件如下
```
例1：
#cloud-config
ssh_pwauth: True
chpasswd:
  list: |
    root:12345
  expire: False

例2：
#!/bin/bash
echo 'Extra user data here'
```

**Nova metadata**
- nova metadata包括：meta_data.json 和 network_data.json
- meta_data.json 包含 nova 的特定信息
```json
{
   "random_seed": "yu5ZnkqF2CqnDZVAfZgarG...",
   "availability_zone": "nova",
   "keys": [
       {
         "data": "ssh-rsa AAAAB3NzaC1y...== Generated by Nova\n",
         "type": "ssh",
         "name": "mykey"
       }
   ],
   "hostname": "test.novalocal",
   "launch_index": 0,
   "meta": {
      "priority": "low",
      "role": "webserver"
   },
   "devices": [
       {
         "type": "nic",
         "bus": "pci",
         "address": "0000:00:02.0",
         "mac": "00:11:22:33:44:55",
         "tags": ["trusted"]
       },
       {
         "type": "disk",
         "bus": "ide",
         "address": "0:0",
         "serial": "disk-vol-2352423",
         "path": "/dev/sda",
         "tags": ["baz"]
       }
   ],
   "project_id": "f7ac731cc11f40efbc03a9f9e1d1d21f",
   "public_keys": {
       "mykey": "ssh-rsa AAAAB3NzaC1y...== Generated by Nova\n"
   },
   "name": "test"
}
```
- network_data.json 包含从 neutron 查询到的信息
```json
{
    "links": [
        {
            "ethernet_mac_address": "fa:16:3e:9c:bf:3d",
            "id": "tapcd9f6d46-4a",
            "mtu": null,
            "type": "bridge",
            "vif_id": "cd9f6d46-4a3a-43ab-a466-994af9db96fc"
        }
    ],
    "networks": [
        {
            "id": "network0",
            "link": "tapcd9f6d46-4a",
            "network_id": "99e88329-f20d-4741-9593-25bf07847b16",
            "type": "ipv4_dhcp"
        }
    ],
    "services": [
        {
            "address": "8.8.8.8",
            "type": "dns"
        }
    ]
}
```
- 在创建虚机时，用户也可以写入一些元数据：
```
nova boot --meta <key=value>
```
**Vendor data**
由nova-api-metadata服务启动时指定。