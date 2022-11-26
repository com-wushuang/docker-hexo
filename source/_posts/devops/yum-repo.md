---
title: YUM
date: 2022-11-22 10:17:23
tags:
categories: devops
---

## yum 运行原理
`yum` 是 `C/S` 架构，一部分是 `yum` 服务器，一部分是`client`的`yum`工具。下面分别介绍两部分工作原理。

### yum服务器
- 所有要发行的 `rpm` 包都放在 `yum` 服务器上以提供别人来下载。
- 服务器只要提供简单的下载就可以了，`ftp`或者 `httpd` 的形式都可以。
- 服务器有一个最重要的环节就是整理出每个 `rpm` 包的基本信息，包括 `rpm` 包对应的版本号， `conf` 文件，`binary`信息，以及很关键的依赖信息。
- 服务器上提供了`createrepo`工具，用于把`rpm`包的基本概要信息做成一张"清单"，这张"清单""就是描述每个`rpm`包的`spec`文件中信息。

### yum client端
- `client`每次调用`yum install`或者`search`的时候，都会去解析`/etc/yum.repos.d`下面所有以`.repo`结尾的配置文件，这些配置文件指定了`yum`服务器的地址。
- `yum` 会定期去"更新" `yum` 服务器上的 `rpm` 包"清单"，然后把"清单"下载保存到 `yum` 自己的 `cache` 里面，根据 `/etc/yum.conf` 里配置(默认是在 `/var/cache/yum` 下面)。
- 每次调用 `yum` 装包的时候都会去这个 `cache` 目录下去找"清单"，根据"清单"里的 `rpm` 包描述从而来确定安装包的名字，版本号，所需要的依赖包等。
- 然后再去 `yum` 服务器下载 `rpm` 包安装(前提是不存在rpm包的cache)。


## 搭建局域网yum源
- 需要在局域网访问，首先需要一个web服务器，比如`apache httpd`或者`nginx`均可以，`centos`默认是安装了`httpd`的，可以直接用这个
```
# 命令启动服务
systemctl start httpd.service 

# 服务器的根目录在/var/www/html下，可以解析静态页面以及显示目录列表了

# 配置文件
/etc/httpd/conf/httpd.conf
```

- rpm存储位置
``` 
创建目录
mkdir -p /var/www/html/yum-custom

# 将自己的 rpm包放到这个目录下面。 

# 安装索引创建命令
yum -y install createrepo 

# 重建索引，如果已存在要先删除
createrepo . 
```


- 配置仓库设置
```
cd /etc/yum.repos.d/;

# 备份
tar -zcvf repo-bk.tar.gz CentOS-* ;    

# 然后将这些repo删除 
rm -rf CentOS-* 
              
# 新增自定义的repo文件，
vi yum-custom.repo

# 添加下面的内容
[yum-custom]
name=yum-custom
baseurl=http://10.110.19.60/yum-custom/
#baseurl=file:///var/www/html/yum-custom
enable=1
gpgcheck=0
```
- 验证生效
```
# 刷新
yum clean all

# 查看最新的yum源信息
yum repolist

# 到这里本地yum源就配置好了，其他机器只要设置好repo文件，就可以直接使用yum命令安装自定义源中的软件了

# 可以建立缓存，提高使用和查询效率
yum makecache;
```
## 更新本地yum源
手动添加 rpm 包             
```
# 找到yum原的具体存储位置
cd /var/www/html/yum/centos/7


# 查看文件列表可以看到各个rpm包和一个repodata文件夹，这个文件夹中的repomd.xml文件就是记录yum源文件依赖关系的，新增yum源的主要工作就是更新依赖关系


# 删除repodata文件夹，
rm -rf repodata

# 将需要添加的rpm包上传到yum源的目录下面

# 创建新的repodata文件夹
createrepo .

# 如果提示命令不存在，先安装
yum -y install createrepo
          
# 刷新
yum clean all

# 新的rpm包就可以在本地yum源中生效了
yum makecache
```

## yum clean all 原理
一般yum下载的包和header文件都存储在/var/cache/yum中，所以会越来越大，如果觉得占用磁盘空间过大就可以使用此命令去删除。

## yum makecache 原理
