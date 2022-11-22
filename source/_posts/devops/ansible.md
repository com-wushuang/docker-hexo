---
title: ansible CLI
date: 2022-11-22 10:17:23
tags:
categories: devops
---
#  ansible 的一些概念
## Control node
主控节点，安装了ansible工具的机器。ansible工具的工作模式是，在主控节点上，使用ssh连接被控节点，批量的执行相关的命令。
## Managed nodes
被控节点，想要被主控节点管理的机器，一般是多个机器。一般不会安装ansible。
## Inventory
定义hosts（也就是被控节点）的文件。一般是声明了hosts的IP或域名。更高级的情形下会对hosts进行分组、或对hosts进行一些参数配置。
```
[all:vars]
ansible_ssh_user=secure
ansible_ssh_port=10000
ansible_become=yes
ansible_become_method=sudo
ansible_become_user=root
extension=false

[os_ha]
10.101.8.46
10.101.8.47

[sdk_proxy_ha]
10.101.8.43
10.101.8.44
```
## Modules
模块实现了特定的功能，用户在使用时，只要知道模块的名称和用法，就可以在ansible命令中引用了。

## ansible ClI 格式
```
ansible [pattern] -m [module] -a "[module options]"
```
- pattern 指定命令执行的机器。可以是所有host、某个group、或者表达式匹配等。
- module 模块，简单说就是执行什么操作。

## 参数选项
```
ansible-playbook -i /path/to/my_inventory_file -u my_connection_user -k -f 3 -T 30 -t my_tag -m /path/to/my_modules -b -K my_playbook.yml
```
- `-i` - uses my_inventory_file in the path provided for inventory to match the pattern.
- `-u` - connects over SSH as my_connection_user.
- `-k` - asks for password which is then provided to SSH authentication.
- `-f` - allocates 3 forks.
- `-T` - sets a 30-second timeout.
- `-t` - runs only tasks marked with the tag my_tag.
- `-m` - loads local modules from /path/to/my/modules.
- `-b` - executes with elevated privileges (uses become).
- `-K` - prompts the user for the become password.

# 简单例子

## Rebooting servers
```
ansible atlanta -a "/sbin/reboot"
```
上面的命令没有指明module，ansible 默认的module 是 ansible.builtin.command。

```
ansible atlanta -a "/sbin/reboot" -f 10
```
默认情况下，ansible执行命令时使用5个并行的进程，-f 可以自定义这个数量。

```
ansible atlanta -a "/sbin/reboot" -f 10 -u username
```
指定用什么用户连接被控节点。

```
ansible atlanta -a "/sbin/reboot" -f 10 -u username --become [--ask-become-pass]
```
有时候需要切换到root用户去进行某些操作，这个时候需要加上 --become 选项。--ask-become-pass 是输入密码提示的选项。

## Managing files
```
# copy file
ansible atlanta -m ansible.builtin.copy -a "src=/etc/hosts dest=/tmp/hosts"
```

```
# create directory
ansible webservers -m ansible.builtin.file -a "dest=/path/to/c mode=755 owner=mdehaan group=mdehaan state=directory"
```

```
# delete directory
ansible webservers -m ansible.builtin.file -a "dest=/path/to/c state=absent"
```

## Managing packages

```
# install
ansible webservers -m ansible.builtin.yum -a "name=acme state=present"

# install specific version
ansible webservers -m ansible.builtin.yum -a "name=acme-1.5 state=present"

# install latest version
ansible webservers -m ansible.builtin.yum -a "name=acme state=latest"

# uninstall 
ansible webservers -m ansible.builtin.yum -a "name=acme state=absent"
```

## Managing services
```
# start
ansible webservers -m ansible.builtin.service -a "name=httpd state=started"

# restart
ansible webservers -m ansible.builtin.service -a "name=httpd state=restarted"

# stop
ansible webservers -m ansible.builtin.service -a "name=httpd state=stopped"
```

## Gathering facts
```
ansible all -m ansible.builtin.setup
```
有过滤规则，可参考setup module 的文档。

# 定位OpenStack问题时的妙用
**前提**
如果openstack是用ansible部署的，那么部署机器就是主控节点，其他的节点就是被控节点。不出意外的话，部署机器上会有一个playbooks目录，里面是openstack部署的脚本，也会有相应的 inventory file，也就是hosts文件。同时，部署机器到其他节点的ssh登录也是打通的（在部署openstack时打通的）。

**一般情况下的问题定位**
创建虚拟机失败，定位问题首先得在 controller 各个节点上nova-api.log日志文件中用虚拟机name搜索相关日志。 ，需要一台一台登录节点。

**ansible**
我们在部署机上用ansible 命令就可以做到，不用一个一个节点登录。假如host文件定义如下：
```
[all:vars]
ansible_ssh_user=secure
ansible_become=yes
ansible_become_method=sudo
ansible_become_user=root
extension=false
ansible_ssh_port=10000
ansible_python_interpreter=/usr/bin/python3.7

[kgc_server] #三台控制节点
10.9.200.146
10.9.200.147
10.9.200.148

[compute]   #计算节点
10.9.200.14
10.9.200.15
10.9.200.16
10.9.200.17
10.9.200.18

....
```
- `nova show <uuid> --deleted` :获取主机name
- `ansible kgc_server -m shell -a "grep <name> /var/log/nova/nova-api.log"` :获取创建参数和req-id
- `ansible kgc_server -m shell -a "grep <req-id> /var/log/nova/nova-scheduler.log"` :获取调度日志
- `ansible compute -m shell -a "grep <req-id> /var/log/nova/nova-compute.log"` :获取计算节点日志