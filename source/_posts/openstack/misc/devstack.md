---
title:  devstack
date: 2022-12-07 15:18:17
tags:
categories: OpenStack
---

# 搭建
## 安装系统
安装 devstack 会对你的系统做很多改变，最好的方式是使用虚拟机或者容器。

## 系统初始化配置
在安装 devstack 前做以下配置
- 软件源替换
- pip源替换
- pip版本升级

## 添加 stack user
- 官网说为了安全，最好新建一个用户 stack 去安装 devstack。
- 强烈建议不要这么做 : 本来就是虚拟机环境，添加用户浪费时间同时会引起一些不必要的权限问题，直接用 root就行

## 下载 DevStack
- 下面的方式会安装最新版本的 openstack ：
```shell
# 安装最新版本的 openstack
cd /opt && git clone https://opendev.org/openstack/devstack
cd devstack
```
- 如果想安装指定版本的 openstack 比如 queens，如下：
```shell
# 安装指定版本 openstack
cd /opt && git clone https://opendev.org/openstack/devstack -b stable/queens
cd devstack
```

## 创建配置文件
```shell
# 工作目录
pwd
/opt/devstack

# cp 一份配置文件模板
cp samples/local.conf ./

# 修改配置文件，增加配置，加速openstack源代码 clone
GIT_BASE=http://git.trystack.cn
```

## 开始安装
```
./stack.sh
```

## 会遇到的问题及解决方法
### 系统选择
- 官方建议系统选择 ubuntu 22.04，但是这个前提是你安装的 openstack 是最新的版本的情况下。
- 如果在一开始安装就报错，那么建议低版本的 openstack 配套低版本的 ubuntu 系统。
- 至于什么版本的 openstack 对应什么版本的 ubuntu ，官方没有说明，只能尝试。

### openstack 源码 clone
- 一般情况下 devstack 的脚本会根据devstack的版本去下载 openstack 对应的源码版本。
- 比如在devstack的版本是 stable/queens，那么就回去下 stable/queens版本的openstack。
- 但是有个坑是，devstack有stable/queens版本，openstack没有stable/queens版本，于是安装过程中会报仓库未找到的错。
- 解决方法:
    - 一、手动下载对应的版本(在 /opt 目录下)，然后重新运行脚本 ./stack.sh
    - 二、配置文件指定 openstack 源码版本
```ini
NOVA_REPO=$GIT_BASE/openstack/nova.git
NOVA_BRANCH=master
```

### tempest 安装
- 默认会安装 tempest 项目，tempest 项目本身还要用 tox 创建venv虚拟环境，然后 pip install 依赖，非常浪费时间且容易出错。
- 一、直接把 extras.d 下的 80-tempest.sh 文件删除，脚本就不会帮你安装tempest了。
- 二、配置文件
```ini
disable_service tempest
```
- 三、改 devstack 脚本源码 stackrc ，里面有默认安装的服务，把tempest去掉就好。

### 终极方法
不管遇到什么问题，终极解决方法都是
- 查看官方文档：https://docs.openstack.org/devstack/latest
- 查看源代码：https://github.com/openstack/devstack

# 使用
使用方法同样是参考官方文档：https://docs.openstack.org/devstack/latest/development.html

