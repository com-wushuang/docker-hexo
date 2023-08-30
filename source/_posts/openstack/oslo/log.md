---
title:  openstack 基础库之 oslo_log
date: 2023-08-30 06:18:17
tags:
categories: OpenStack
---

## python 内建日志库
- 使用样例
```python
import logging

# 日志句柄
LOG = logging.getLogger(__name__)

# 以编码的方式对日志做基础的配置
logging.basicConfig(level=logging.INFO)

LOG.info("Python Standard Logging")
LOG.warning("Python Standard Logging")
LOG.error("Python Standard Logging")
```
- 输出：
```log
INFO:__main__:Python Standard Logging
WARNING:__main__:Python Standard Logging
ERROR:__main__:Python Standard Logging
```
## oslo_log 使用方式
```python
from oslo_config import cfg
from oslo_log import log as logging

# 所有关于日志的配置都使用 CONF 对象完成
# 所以你可以通过配置文件去配置日志，而不用通过编码的方式去配置
LOG = logging.getLogger(__name__)
CONF = cfg.CONF
DOMAIN = "demo"

logging.register_options(CONF)

# 配置logging
logging.setup(CONF, DOMAIN)

# Oslo Logging uses INFO as default
LOG.info("Oslo Logging")
LOG.warning("Oslo Logging")
LOG.error("Oslo Logging")
```
- 输出格式标准化：
```log
2023-08-30 07:52:35.614 78105 INFO __main__ [-] Oslo Logging
2023-08-30 07:52:35.615 78105 WARNING __main__ [-] Oslo Logging
2023-08-30 07:52:35.615 78105 ERROR __main__ [-] Oslo Logging
```
## nova 组件使用
- 在服务启动是，初始化配置，然后再直接使用 `logging.setup` 配置日志
```python
CONF = nova.conf.CONF


def main():
    config.parse_args(sys.argv)
    logging.setup(CONF, "nova")
```
