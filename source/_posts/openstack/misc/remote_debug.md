---
title:  pycharm远程调试openstack
date: 2022-12-07 15:18:17
tags:
categories: OpenStack
---
## 准备
开发机器信息：
- pycharm 版本：2021.1.3

虚拟机信息：
- devstack 版本：queens
- devstack openstack 版本：queens
- python 版本：2.7.12

## 基本原理
![pycharm 远程调试原理图](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%20%E8%BF%9C%E7%A8%8B%E8%B0%83%E8%AF%95%E5%8E%9F%E7%90%86%E5%9B%BE.png)
- Python 远程调试模型其实是一个典型的Server/Client模型。
- 本地 PyCharm 有两个作用：
    - 方便在本地编辑远程机器上的源代码。
    - 启动 Python Debug Server，监听本地的某个端口，等待 Client 的接入。
- 远程机器运行的 Python 程序调用 pydevd_pycharm 库，连接到服务端。
- 断点是打在远程机器的源代码上，只是我们使用了远程开发的模式，所以看上去是写在本地的，实际上确实也是写在本地的，只是代码会被同步到远程。但实际上我们要保证的是远程源码打上了断点。

## 配置过程
### 创建本地工程
此步主要完成本地代码与远程代码的同步，可以将远程代码下载到本地，也可以将本地在 Pycharm 中修改的代码很快部署到远程环境中。
![pycharm创建新的工程](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E5%88%9B%E5%BB%BA%E6%96%B0%E7%9A%84%E5%B7%A5%E7%A8%8B.png)
- 解释器选择远程解释器
- 不要自动创建 main.py
- 这里我使用了先前配置的解释器
- 新建一个远程解释器如下:
![pycharm解释器设置](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E8%A7%A3%E9%87%8A%E5%99%A8%E8%AE%BE%E7%BD%AE.png)
- 【设置】中选择【添加】
- 远程解释器配置
![pycharm远程解释器配置](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E8%BF%9C%E7%A8%8B%E8%A7%A3%E9%87%8A%E5%99%A8%E9%85%8D%E7%BD%AE.png)
![pycharm远程解释器文件映射](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E8%BF%9C%E7%A8%8B%E8%A7%A3%E9%87%8A%E5%99%A8%E6%96%87%E4%BB%B6%E6%98%A0%E5%B0%84.png)
- 取消自动上传项目文件到服务器，因为一开始是空项目，我们要从远程下载代码，而不是从本地同步代码到远程
- 同步文件映射：本地项目目录 —> 远程项目目录
- 下载远程代码到本地，这样我们本地就有了一份和远程一模一样的源代码了
![pycharm从远程下载代码到本地](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E4%BB%8E%E8%BF%9C%E7%A8%8B%E4%B8%8B%E8%BD%BD%E4%BB%A3%E7%A0%81%E5%88%B0%E6%9C%AC%E5%9C%B0.png)

### Debug Server配置
Debug Server 由 pycharm 负责启动，配置如下：
![debug_server配置](https://raw.githubusercontent.com/com-wushuang/pics/main/debug_server%E9%85%8D%E7%BD%AE.png)
- 在本地利用 PyCharm 启动了一个Debug Server
- 上述配置的 ip 是本机的，端口也是本地端口

## 开始调试
### 准备工作
PyCharm 很好的一点是，他在配置debug server 的时候给你提示了怎么使用，如上图，步骤如下：
- 在远程环境安装debug client 的包:
```
pip install pydevd-pycharm~=211.7628.24
```
- 在源码中需要打断点的地方引用库
```
import pydevd_pycharm
pydevd_pycharm.settrace('172.25.5.233', port=12345, stdoutToServer=True, stderrToServer=True)
```
### 打断点
![pycharm打断点](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E6%89%93%E6%96%AD%E7%82%B9.png)

### 启动Debug Server
![pycharm启动debug server](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E5%90%AF%E5%8A%A8debug%20server.png)
- 只能感叹，PyCharm的用户体验做的是真好，写的是真清楚，生怕你不知道

### 远端重启服务
- 查看服务启动命令 `systemctl cat devstack@n-api`
```shell
# 查看服务启动命令
systemctl cat devstack@n-api
# /etc/systemd/system/devstack@n-api.service

[Unit]
Description = Devstack devstack@n-api.service

[Service]
RestartForceExitStatus = 100
NotifyAccess = all
Restart = always
KillMode = process
Type = notify
ExecReload = /bin/kill -HUP $MAINPID
ExecStart = /usr/local/bin/uwsgi --procname-prefix nova-api --ini /etc/nova/nova-api-uwsgi.ini
User = stack
SyslogIdentifier = devstack@n-api.service

[Install]
WantedBy = multi-user.target
```
- 停掉服务 `systemctl stop devstack@n-api`
- 用 bash 启动  `/usr/local/bin/uwsgi --procname-prefix nova-api --ini /etc/`
- 用 `nova flavor-list` 触发断点, 就能开始调试咯，如下图:
![python_debug_client连接debug_server](https://raw.githubusercontent.com/com-wushuang/pics/main/python_debug_client%E8%BF%9E%E6%8E%A5debug_server.png)
- 调试变量：
![pycharm远程调试变量](https://raw.githubusercontent.com/com-wushuang/pics/main/pycharm%E8%BF%9C%E7%A8%8B%E8%B0%83%E8%AF%95%E5%8F%98%E9%87%8F.png)