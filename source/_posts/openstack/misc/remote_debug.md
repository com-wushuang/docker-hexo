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

## 通用的debug方法
pycharm 在测试环境 debug 固然方便，但是一旦遇到线上环境网络不通畅的情况，就没法进行debug了。因此还是很有必要掌握通用的debug方法。

### pdb
pdb 调试时必须要手动启动服务的场景。如果服务是 systemd 管理的方式，那么需要先把服务停掉，然后手动启动，比如在 devstack 环境下调试时：
- 查看服务启动命令
```shell
systemctl show devstack@n-sch.service -p ExecStart
```
- 停止服务
```
systemctl stop devstack@n-sch.service
```
- 设置断点
```
import pdb; pdb.set_trace()
```
- 手动启动
```
/usr/local/bin/nova-scheduler --config-file /etc/nova/nova.conf
```
- 有些服务，是在某些 Group 中启动的（比如nova-compute），那么执行方式不一样，先查看 Group
```
systemctl cat devstack@n-cpu.service | grep Group
Group = libvirt
```
- 用 sg 工具执行
```
sg libvirt -c '/usr/local/bin/nova-compute --config-file /etc/nova/nova-cpu.conf'
```
### remote-pdb
`remote-pdb` 不在乎程序是用什么方式运行的，只要能够能连接到程序就行(源码执行环境能够 pip 安装依赖)。
- 源码环境安装依赖
```shell
pip install remote-pdb
```
- 打上断点
```shell
from remote_pdb import RemotePdb; RemotePdb('127.0.0.1', 4444).set_trace()
```
- telnet 连接
```
telnet 127.0.0.1 4444
```

## pdb 常用命令

1、查看源代码
- 命令：l

2、添加断点
- 命令：b
```shell
# 参数：
# filename文件名，断点添加到哪个文件，如test.py
# lineno断点添加到哪一行
# function：函数名，在该函数执行的第一行设置断点

# 说明：
# 1.不带参数表示查看断点设置
# 2.带参则在指定位置设置一个断点

b lineno
b filename:lineno 
b functionname
```

3、添加临时断点
- 命令：tbreak
```shell
# 参数：
# 同b

# 说明：
# 执行一次后时自动删除（这就是它被称为临时断点的原因）

tbreak lineno
tbreak filename:lineno
tbreak functionname
```

4、清除断点
- 命令：cl
```shell
# 参数：
# bpnumber 断点序号（多个以空格分隔）

# 说明：
# 1.不带参数用于清除所有断点，会提示确认（包括临时断点）
# 2.带参数则清除指定文件行或当前文件指定序号的断点

cl filename:lineno
cl bpnumber [bpnumber ...]
```

5、打印变量值
- 命令：p expression
```shell
# 参数：
# expression Python表达式
```

6、逐行调试命令
包括 s ，n ， r 这3个相似的命令，区别在如何对待函数上

- 命令1：s

```
# 说明：
# 执行下一行（能够进入函数体）
```


- 命令2：n 
```shell
# 说明：
# 执行下一行（不会进入函数体）
```

- 命令3：r 
```shell
# 说明：
# 执行下一行（在函数中时会直接执行到函数返回处）
```
7、非逐行调试命令
命令1：c
```shell
# 说明：
# 持续执行下去，直到遇到一个断点
```

命令2：unt lineno
```shell
# 说明：
# 持续执行直到运行到指定行（或遇到断点）
```

- 命令3：j lineno
```shell
# 说明：
# 直接跳转到指定行（注意，被跳过的代码不执行）
```

8、查看函数参数
- 命令：a
```shell
# 说明：
# 在函数中时打印函数的参数和参数的值
```

9、打印变量类型
- 命令：whatis expression
```shell
# 说明：
# 打印表达式的类型，常用来打印变量值
```

10、启动交互式解释器
- 命令：interact
```shell
# 说明：
# 启动一个python的交互式解释器，使用当前代码的全局命名空间（使用ctrl+d返回pdb）
```

11、打印堆栈信息
- 命令：w
```shell
# 说明：
# 打印堆栈信息，最新的帧在最底部。箭头表示当前帧。
```

12、退出pdb
- 命令：q
