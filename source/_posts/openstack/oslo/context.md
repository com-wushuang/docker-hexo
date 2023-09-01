---
title:  openstack 基础库之 oslo_context
date: 2023-09-01 06:18:17
tags:
categories: OpenStack
---

## 官方使用
- 例1：增加日志的上下文
```python
from oslo_config import cfg
from oslo_context import context
from oslo_log import log as logging

CONF = cfg.CONF
DOMAIN = "demo"

logging.register_options(CONF)
logging.setup(CONF, DOMAIN)

LOG = logging.getLogger(__name__)

LOG.info("Message without context")
# ids in Openstack are 32 characters long
# For readability a shorter id value is used
context.RequestContext(user='6ce90b4d',
                       tenant='d6134462',
                       project_domain='a6b9360e')
LOG.info("Message with context")
```
- 输出：会加上上下文信息
```log
2016-01-21 17:30:50.263 12201 INFO __main__ [-] Message without context
2016-01-21 17:30:50.264 12201 INFO __main__ [req-e591e881-36c3-4627-a5d8-54df200168ef 6ce90b4d d6134462 - - a6b9360e] Message with context
```
- 思考：`context.RequestContext()` 仅仅新建一个对象为什么能够改变 `Log` 的行为?

## context 实现原理
`oslo.context` 包代码比较少，只有一个类，如下：
```python
class RequestContext(object):
    def __init__(
        self,
        auth_token: ty.Optional[str] = None,
        user_id: ty.Optional[str] = None,
        project_id: ty.Optional[str] = None,
        domain_id: ty.Optional[str] = None,
        user_domain_id: ty.Optional[str] = None,
        project_domain_id: ty.Optional[str] = None,
        is_admin: bool = False,
        read_only: bool = False,
        show_deleted: bool = False,
        request_id: ty.Optional[str] = None,
        resource_uuid: ty.Optional[str] = None,
        overwrite: bool = True,
        roles: ty.Optional[ty.List[str]] = None,
        user_name: ty.Optional[str] = None,
        project_name: ty.Optional[str] = None,
        domain_name: ty.Optional[str] = None,
        user_domain_name: ty.Optional[str] = None,
        project_domain_name: ty.Optional[str] = None,
        is_admin_project: bool = True,
        service_token: ty.Optional[str] = None,
        service_user_id: ty.Optional[str] = None,
        service_user_name: ty.Optional[str] = None,
        service_user_domain_id: ty.Optional[str] = None,
        service_user_domain_name: ty.Optional[str] = None,
        service_project_id: ty.Optional[str] = None,
        service_project_name: ty.Optional[str] = None,
        service_project_domain_id: ty.Optional[str] = None,
        service_project_domain_name: ty.Optional[str] = None,
        service_roles: ty.Optional[ty.List[str]] = None,
        global_request_id: ty.Optional[str] = None,
        system_scope: ty.Optional[str] = None,
    ):
        # setting to private variables to avoid triggering subclass properties
        self._user_id = user_id
        self._project_id = project_id
        self._domain_id = domain_id
        self._user_domain_id = user_domain_id
        self._project_domain_id = project_domain_id

        self.auth_token = auth_token
        self.user_name = user_name
        self.project_name = project_name
        self.domain_name = domain_name
        self.system_scope = system_scope
        self.user_domain_name = user_domain_name
        self.project_domain_name = project_domain_name
        self.is_admin = is_admin
        self.is_admin_project = is_admin_project
        self.read_only = read_only
        self.show_deleted = show_deleted
        self.resource_uuid = resource_uuid
        self.roles = roles or []

        self.service_token = service_token
        self.service_user_id = service_user_id
        self.service_user_name = service_user_name
        self.service_user_domain_id = service_user_domain_id
        self.service_user_domain_name = service_user_domain_name
        self.service_project_id = service_project_id
        self.service_project_name = service_project_name
        self.service_project_domain_id = service_project_domain_id
        self.service_project_domain_name = service_project_domain_name
        self.service_roles = service_roles or []

        if not request_id:
            request_id = generate_request_id()
        self.request_id = request_id
        self.global_request_id = global_request_id
        if overwrite or not get_current():
            self.update_store()
```
- 构造方法：将构造参数设置为实例的属性值，最后再用这一行调用对这些设置的值进行存储 `self.update_store()`

```python
    def update_store(self) -> None:
        """Store the context in the current thread."""
        _request_store.context = self
```
- `_request_store` 是一个模块级的变量，在模块加载的时候初始化
```python
import threading
_request_store = threading.local()
```
> 线程本地存储`（Thread-local Storage）`是一种机制，允许每个线程在共享相同全局变量的情况下，拥有自己的独立变量副本。通过线程本地存储，每个线程可以独立地访问和修改自己的变量副本，而不会影响其他线程的副本

>`_request_store` 用于在多线程环境下存储与请求相关的数据，以便每个线程可以访问和修改自己的请求数据，而不会与其他线程的数据发生冲突

- 在一个线程中 `_request_store` 相当于一个全局的变量
- 在不通的线程中，`_request_store` 相互隔离

## log 使用
`oslo_log` 有一个`ContextFormatter` 他就是用来 context 来格式化日志输出的，他会引用线程本地存储。