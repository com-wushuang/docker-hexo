---
title:  openstack 基础库之 oslo_service
date: 2023-08-31 05:18:17
tags:
categories: OpenStack
---

## 官方示例
- 例1：根据不同的 work 数选择不同的 Launcher
```python
from oslo_config import cfg
from oslo_service import service

CONF = cfg.CONF

# ServiceLauncher
service_launcher = service.ServiceLauncher(CONF)
service_launcher.launch_service(service.Service())

# ProcessLauncher
process_launcher = service.ProcessLauncher(CONF, wait_interval=1.0)
process_launcher.launch_service(service.Service(), workers=2)
```
- 例2：让库自动识别选择
```python
from oslo_config import cfg
from oslo_service import service

CONF = cfg.CONF

launcher = service.launch(CONF, service.Service(), workers=3)

## 实现方式如下：
def launch(conf, service, workers=1, restart_method='reload'):

    if workers is not None and not isinstance(workers, int):
        raise TypeError(_("Type of workers should be int!"))

    if workers is not None and workers <= 0:
        raise ValueError(_("Number of workers should be positive!"))

    if workers is None or workers == 1:
        launcher = ServiceLauncher(conf, restart_method=restart_method)
    else:
        launcher = ProcessLauncher(conf, restart_method=restart_method)
    launcher.launch_service(service, workers=workers)

    return launcher

```

## 源码分析
### oslo.service 层
一、 oslo_service.Service 类
```python
class Service(ServiceBase):
    """Service object for binaries running on hosts."""

    def __init__(self, threads=1000):
        self.tg = threadgroup.ThreadGroup(threads)

    def reset(self):
        """Reset a service in case it received a SIGHUP."""

    def start(self):
        """Start a service."""

    def stop(self, graceful=False):
        """Stop a service.

        :param graceful: indicates whether to wait for all threads to finish
               or terminate them instantly
        """
        self.tg.stop(graceful)

    def wait(self):
        """Wait for a service to shut down."""
        self.tg.wait()
```
- `oslo_service.Service` 类继承了 `ServiceBase`, `ServiceBase` 是一个抽象的类
- 总结来说 `oslo_service.Service` 是一个抽象类 `ServiceBase` 的简单实现
- `oslo_service.Service` 的每个实例都会包含一个 `ThreadGroup`，这是一个线程池
```python
    def __init__(self, threads=1000):
        self.tg = threadgroup.ThreadGroup(threads)
```
二、oslo_service.Launcher类
```python
class Launcher(object):
    """Launch one or more services and wait for them to complete."""

    def __init__(self, conf, restart_method='reload'):
        """Initialize the service launcher.

        :param restart_method: If 'reload', calls reload_config_files on
            SIGHUP. If 'mutate', calls mutate_config_files on SIGHUP. Other
            values produce a ValueError.
        :returns: None

        """
        self.conf = conf
        conf.register_opts(_options.service_opts)
        self.services = Services(restart_method=restart_method)
        self.backdoor_port = (
            eventlet_backdoor.initialize_if_enabled(self.conf))
        self.restart_method = restart_method

    def launch_service(self, service, workers=1):
        """Load and start the given service.

        :param service: The service you would like to start, must be an
                        instance of :class:`oslo_service.service.ServiceBase`
        :param workers: This param makes this method compatible with
                        ProcessLauncher.launch_service. It must be None, 1 or
                        omitted.
        :returns: None

        """
        if workers is not None and workers != 1:
            raise ValueError(_("Launcher asked to start multiple workers"))
        _check_service_base(service)
        service.backdoor_port = self.backdoor_port
        self.services.add(service)

    def stop(self):
        """Stop all services which are currently running.

        :returns: None

        """
        self.services.stop()

    def wait(self):
        """Wait until all services have been stopped, and then return.

        :returns: None

        """
        self.services.wait()

    def restart(self):
        """Reload config files and restart service.

        :returns: The return value from reload_config_files or
          mutate_config_files, according to the restart_method.
        """
        if self.restart_method == 'reload':
            self.conf.reload_config_files()
        else:  # self.restart_method == 'mutate'
            self.conf.mutate_config_files()
        self.services.restart()
```
- `launch_service` 是库对外的 `api` 这一点我们在官方的示例中也看的到。
- `Launcher` 类有两个子类， `ServiceLauncher` 、 `ProcessLauncher`。是该库对外的 `api` ，在上面的官方示例中也可以看出来，他们主要是重写了 `__init__` 和 `launch_service`
```python
# 只重写了 __init__ 方法
class ServiceLauncher(Launcher):
    """Runs one or more service in a parent process."""
    def __init__(self, conf, restart_method='reload'):
        super(ServiceLauncher, self).__init__(
            conf, restart_method=restart_method)
        self.signal_handler = SignalHandler()
```
```python
# __init__ 、 launch_service 都重写了
class ProcessLauncher(object):
    """Launch a service with a given number of workers."""

    def __init__(self, conf, wait_interval=0.01, restart_method='reload'):
        """Constructor.

        :param conf: an instance of ConfigOpts
        :param wait_interval: The interval to sleep for between checks
                              of child process exit.
        :param restart_method: If 'reload', calls reload_config_files on
            SIGHUP. If 'mutate', calls mutate_config_files on SIGHUP. Other
            values produce a ValueError.
        """
        self.conf = conf
        conf.register_opts(_options.service_opts)
        self.children = {}
        self.sigcaught = None
        self.running = True
        self.wait_interval = wait_interval
        self.launcher = None
        rfd, self.writepipe = os.pipe()
        self.readpipe = eventlet.greenio.GreenPipe(rfd, 'r')
        self.signal_handler = SignalHandler()
        self.handle_signal()
        self.restart_method = restart_method
        if restart_method not in _LAUNCHER_RESTART_METHODS:
            raise ValueError(_("Invalid restart_method: %s") % restart_method)

    def launch_service(self, service, workers=1):
        """Launch a service with a given number of workers.

       :param service: a service to launch, must be an instance of
              :class:`oslo_service.service.ServiceBase`
       :param workers: a number of processes in which a service
              will be running
        """
        _check_service_base(service)
        wrap = ServiceWrapper(service, workers)

        # Hide existing objects from the garbage collector, so that most
        # existing pages will remain in shared memory rather than being
        # duplicated between subprocesses in the GC mark-and-sweep. (Requires
        # Python 3.7 or later.)
        if hasattr(gc, 'freeze'):
            gc.freeze()

        LOG.info('Starting %d workers', wrap.workers)
        while self.running and len(wrap.children) < wrap.workers:
            self._start_child(wrap)
```

三、oslo_service.Services类
- `ServiceLauncher` 构造方法调用了基类 `Launcher` 的构造方法 `__init__` 给 `services` 属性赋值，他是一个重要的包内的类，对库的调用方其实是不感知的，但是它很重要。
- `ServiceLauncher` 的 `launcher_service` 方法会调用 `services.add` 方法启动一个线程然后执行 `run_service` 方法，在 `run_service` 中又去调用 `service.start()` 方法
```python
class Services(object):

    def __init__(self, restart_method='reload'):
        if restart_method not in _LAUNCHER_RESTART_METHODS:
            raise ValueError(_("Invalid restart_method: %s") % restart_method)
        self.restart_method = restart_method
        self.services = []
        self.tg = threadgroup.ThreadGroup()
        self.done = event.Event()

    def add(self, service):
        """Add a service to a list and create a thread to run it.

        :param service: service to run
        """
        self.services.append(service)
        self.tg.add_thread(self.run_service, service, self.done)

    def stop(self):
        """Wait for graceful shutdown of services and kill the threads."""
        for service in self.services:
            service.stop()

        # Each service has performed cleanup, now signal that the run_service
        # wrapper threads can now die:
        if not self.done.ready():
            self.done.send()

        # reap threads:
        self.tg.stop()

    def wait(self):
        """Wait for services to shut down."""
        for service in self.services:
            service.wait()
        self.tg.wait()

    def restart(self):
        """Reset services.

        The behavior of this function varies depending on the value of the
        restart_method member. If the restart_method is `reload`, then it
        will stop the services, reset them, and start them in new threads.
        If the restart_method is `mutate`, then it will just reset the
        services without restarting them.
        """
        if self.restart_method == 'reload':
            self.stop()
            self.done = event.Event()
        for restart_service in self.services:
            restart_service.reset()
            if self.restart_method == 'reload':
                self.tg.add_thread(self.run_service,
                                   restart_service,
                                   self.done)

    @staticmethod
    def run_service(service, done):
        """Service start wrapper.

        :param service: service to run
        :param done: event to wait on until a shutdown is triggered
        :returns: None

        """
        try:
            service.start()
        except Exception:
            LOG.exception('Error starting thread.')
            raise SystemExit(1)
        else:
            done.wait()
```
### nova 层
#### nova-compute 的启动流程
- 启动代码
```python
from nova import service

def main():
    server = service.Service.create(binary='nova-compute',
                                    topic=compute_rpcapi.RPC_TOPIC)
    service.serve(server)
    service.wait()
```
- 没有直接调用 `oslo_service` 的库, `nova` 层对其做了一层封装，实现了两个类：`Service` 和 `WSGIService`, 它两都是继承自 `oslo_service.Service` 类
- 看下调用的这几个函数
- `service.Service.create`:初始化一个 `Service` 实例
```python
class Service(service.Service):
    # 初始化示例的属性值
    def __init__(self, host, binary, topic, manager, report_interval=None,
                 periodic_enable=None, periodic_fuzzy_delay=None,
                 periodic_interval_max=None, *args, **kwargs):
        super(Service, self).__init__()
        self.host = host
        self.binary = binary
        self.topic = topic
        self.manager_class_name = manager
        self.servicegroup_api = servicegroup.API()
        manager_class = importutils.import_class(self.manager_class_name)
        if objects_base.NovaObject.indirection_api:
            conductor_api = conductor.API()
            conductor_api.wait_until_ready(context.get_admin_context())
        self.manager = manager_class(host=self.host, *args, **kwargs)
        self.rpcserver = None
        self.report_interval = report_interval
        self.periodic_enable = periodic_enable
        self.periodic_fuzzy_delay = periodic_fuzzy_delay
        self.periodic_interval_max = periodic_interval_max
        self.saved_args, self.saved_kwargs = args, kwargs
        self.backdoor_port = None
        setup_profiler(binary, self.host)

    # 在这个函数中对构造参数做一些赋值，然后调用类的构造方法
    @classmethod
    def create(cls, host=None, binary=None, topic=None, manager=None,
               report_interval=None, periodic_enable=None,
               periodic_fuzzy_delay=None, periodic_interval_max=None):
        if not host:
            host = CONF.host
        if not binary:
            binary = os.path.basename(sys.argv[0])
        if not topic:
            topic = binary.rpartition('nova-')[2]
        if not manager:
            manager = SERVICE_MANAGERS.get(binary)
        if report_interval is None:
            report_interval = CONF.report_interval
        if periodic_enable is None:
            periodic_enable = CONF.periodic_enable
        if periodic_fuzzy_delay is None:
            periodic_fuzzy_delay = CONF.periodic_fuzzy_delay

        debugger.init()

        service_obj = cls(host, binary, topic, manager,
                          report_interval=report_interval,
                          periodic_enable=periodic_enable,
                          periodic_fuzzy_delay=periodic_fuzzy_delay,
                          periodic_interval_max=periodic_interval_max)

        return service_obj


_launcher = None


def serve(server, workers=None):
    global _launcher
    if _launcher:
        raise RuntimeError(_('serve() can only be called once'))

    _launcher = service.launch(CONF, server, workers=workers,
                               restart_method='mutate')


def wait():
    _launcher.wait()
```
- `service.serve(server)` : 调用 `oslo_service.service.launch` 的 `api` , 该 `api` 使用如官方示例2。定义如下：
```python
def launch(conf, service, workers=1, restart_method='reload'):

    if workers is not None and not isinstance(workers, int):
        raise TypeError(_("Type of workers should be int!"))

    if workers is not None and workers <= 0:
        raise ValueError(_("Number of workers should be positive!"))

    if workers is None or workers == 1:
        launcher = ServiceLauncher(conf, restart_method=restart_method)
    else:
        launcher = ProcessLauncher(conf, restart_method=restart_method)
    launcher.launch_service(service, workers=workers)

    return launcher
```
- 进入 `oslo_service` 层 ，调用链如下：`launch` -> `Launcher.launch_service` -> `self.services.add(service)` -> `self.tg.add_thread(self.run_service, service, self.done)` -> `self.run_service` -> `service.start()` 这一步已经在上面分析过源码。
- 所以其实最终调用的是 `service` 实例的 `start()` 方法。
```python
    def start(self):
        context.CELL_CACHE = {}

        assert_eventlet_uses_monotonic_clock()

        verstr = version.version_string_with_package()
        LOG.info(_LI('Starting %(topic)s node (version %(version)s)'),
                  {'topic': self.topic, 'version': verstr})
        self.basic_config_check()
        self.manager.init_host()
        self.model_disconnected = False
        ctxt = context.get_admin_context()
        self.service_ref = objects.Service.get_by_host_and_binary(
            ctxt, self.host, self.binary)
        if self.service_ref:
            _update_service_ref(self.service_ref)

        else:
            try:
                self.service_ref = _create_service_ref(self, ctxt)
            except (exception.ServiceTopicExists,
                    exception.ServiceBinaryExists):
                # NOTE(danms): If we race to create a record with a sibling
                # worker, don't fail here.
                self.service_ref = objects.Service.get_by_host_and_binary(
                    ctxt, self.host, self.binary)

        self.manager.pre_start_hook()

        if self.backdoor_port is not None:
            self.manager.backdoor_port = self.backdoor_port

        LOG.debug("Creating RPC server for service %s", self.topic)

        target = messaging.Target(topic=self.topic, server=self.host)

        endpoints = [
            self.manager,
            baserpc.BaseRPCAPI(self.manager.service_name, self.backdoor_port)
        ]
        endpoints.extend(self.manager.additional_endpoints)

        serializer = objects_base.NovaObjectSerializer()

        self.rpcserver = rpc.get_server(target, endpoints, serializer)
        self.rpcserver.start()

        self.manager.post_start_hook()

        LOG.debug("Join ServiceGroup membership for this service %s",
                  self.topic)
        # Add service to the ServiceGroup membership group.
        self.servicegroup_api.join(self.host, self.topic, self)

        if self.periodic_enable:
            if self.periodic_fuzzy_delay:
                initial_delay = random.randint(0, self.periodic_fuzzy_delay)
            else:
                initial_delay = None

            self.tg.add_dynamic_timer(self.periodic_tasks,
                                     initial_delay=initial_delay,
                                     periodic_interval_max=
                                        self.periodic_interval_max)
```
- start 方法中就是用 oslo.message 库创建一个 rpc server。

#### nova-api 的启动流程
- 启动代码
```python
launcher = service.process_launcher()

server = service.WSGIService(api, use_ssl=should_use_ssl)
launcher.launch_service(server, workers=server.workers or 1)
```
- 启动的 `service.WSGIService`这个是 `nova` 层基于 `oslo_service.Service`实现的，表示 wsgi 服务。
- `Launcher` 选择了 `ProcessLauncher`。
- 不管选择什么样的类型，最后都会调用 `Service` 的 `start()` 方法。