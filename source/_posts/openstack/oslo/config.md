---
title:  openstack 基础库之 oslo_config
date: 2023-08-30 05:18:17
tags:
categories: OpenStack
---

## oslo_config 官方示例
- 编写配置 `group` 、 `option`
- 引用 `oslo_config` 包的单例
- 调用该单例对象的 `api` 对配置 `group` 、 `option` 进行注册
- 调用单例对象 `CONF` 的 `__call__` 方法对命令行参数(指定配置文件的位置)进行解析
- 这样以后，配置文件的值便已经注入到了这个单例对象 `CONF` 中
```python
import sys

# Load up the cfg module, which contains all the classes and methods
# you'll need.
from oslo_config import cfg

# Define an option group
grp = cfg.OptGroup('mygroup')

# Define a couple of options
opts = [cfg.StrOpt('option1'),
        cfg.IntOpt('option2', default=42)]

# Register your config group
cfg.CONF.register_group(grp)

# Register your options within the config group
cfg.CONF.register_opts(opts, group=grp)

# Process command line arguments.  The arguments tell CONF where to
# find your config file, which it loads and parses to populate itself.
cfg.CONF(sys.argv[1:])

# Now you can access the values from the config file as
# CONF.<group>.<opt>
print("The value of option1 is %s" % cfg.CONF.mygroup.option1)
print("The value of option2 is %d" % cfg.CONF.mygroup.option2)
```
- 准备一个配置文件
```ini
[mygroup]
option1 = foo
# Comment out option2 to test the default value
# option2 = 123
```
- 调用方式: `python config.py --config-file test.conf`

## nova 组件使用
- `nova.conf` 这个 `pacekage` 用来注册 `nova` 组件的所有配置项
- `CONF` 单例对象在包被导入时被引用,实现方式是使用 `package` 根目录下的 `__init__` 方法
```
CONF = cfg.CONF
```
- 然后同样的调用单例对象的 `api` 对 `group` 、 `options` 进行注册
```
api.register_opts(CONF)
availability_zone.register_opts(CONF)
base.register_opts(CONF)
cache.register_opts(CONF)
cinder.register_opts(CONF)
compute.register_opts(CONF)
...
```
- `nova` 将不同 `group` 的 `options` 放置 `nova.config` 包下的不同模块中
```
cd nova/conf
tree .

.
├── api.py
├── availability_zone.py
├── base.py
├── cache.py
├── cinder.py
├── compute.py
├── conductor.py
├── configdrive.py
```
- 最后在启动服务时使用，例如 `nova-api` 启动，启动服务时会指定配置文件的地址
```python
CONF = nova.conf.CONF


def main():
    config.parse_args(sys.argv) # 启动服务时会指定配置文件的路径
    logging.setup(CONF, "nova") # CONF 加载完毕开始使用
```
## cli
- 可以使用 `oslo-config-generator`查看服务有哪些配置
- 例1：查看 log 相关配置
```shell
oslo-config-generator --namespace oslo.log
```
- 例2：查看 nova 有哪些配置
```shell
oslo-config-generator --namespace nova.conf
```
