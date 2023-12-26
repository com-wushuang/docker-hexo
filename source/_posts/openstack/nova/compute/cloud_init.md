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
- cloud-ini是一种初始化配置工具，它根据数据源中的数据配置计算机。目前内置的数据源有：OpenStack、ConfigDrive、Amazon EC2、Azure等等
- cloud-init在实例内部启动时并不知道从哪里才能够找到实例数据，它会根据预设的一个数据源的列表一个一个查找实例数据，而首个能够找到实例数据的数据源将成为这次启动的数据源。