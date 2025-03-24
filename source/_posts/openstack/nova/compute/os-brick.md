---
title:  nova、cinder是如何使用os-brick的
date: 2025-03-21 10:25:43
tags:
categories: OpenStack
---

# nova 侧挂盘流程
nova/compute/manager.py
```python
    def attach_volume(self, context, instance, bdm):
        # 将bdm字典类型转换成nova/virt/block_device.py 的 DriverVolumeBlockDevice
        driver_bdm = driver_block_device.convert_volume(bdm)
```
nova/compute/manager.py
```python
    def _attach_volume(self, context, instance, bdm):
        try:
            # DriverVolumeBlockDevice 的 attach 方法
            bdm.attach(context, instance, self.volume_api, self.driver, do_driver_attach=True)
```
DriverVolumeBlockDevice.attach -> DriverVolumeBlockDevice._do_attach
```python
    def _do_attach(self, context, instance, volume, volume_api, virt_driver,
                   do_driver_attach):
        # 获取connector
        connector = virt_driver.get_volume_connector(instance)
        if not self['attachment_id']:
            self._legacy_volume_attach(context, volume, connector, instance,
                                       volume_api, virt_driver,
                                       do_driver_attach)
        else:
            self._volume_attach(context, volume, connector, instance,
                                volume_api, virt_driver,
                                self['attachment_id'],
                                do_driver_attach)

    # nova/virt/libvirt/driver.py 
    # 调用os-brick 实现
    from os_brick.initiator import connector
    def get_volume_connector(self, instance):
        root_helper = utils.get_root_helper()
        return connector.get_connector_properties(
            root_helper, CONF.my_block_storage_ip,
            CONF.libvirt.volume_use_multipath,
            enforce_multipath=True,
            host=CONF.host)

    # os-brick/initiator/connector.py
    def get_connector_properties(root_helper, my_ip, multipath, enforce_multipath,
                                host=None, execute=None):

        props = {}
        props['platform'] = platform.machine()
        props['os_type'] = sys.platform
        props['ip'] = my_ip
        props['host'] = host if host else socket.gethostname()

        for item in connector_list:
            connector = importutils.import_class(item)

            if (utils.platform_matches(props['platform'], connector.platform) and
            utils.os_matches(props['os_type'], connector.os_type)):
                props = utils.merge_dict(props,
                                        connector.get_connector_properties(
                                            root_helper,
                                            host=host,
                                            multipath=multipath,
                                            enforce_multipath=enforce_multipath,
                                            execute=execute))

        return props
```
DriverVolumeBlockDevice._legacy_volume_attach
```python
    def _legacy_volume_attach(self, context, volume, connector, instance,
                              volume_api, virt_driver,
                              do_driver_attach=False):

            try:
                virt_driver.attach_volume(
                        context, connection_info, instance,
                        self['mount_device'], disk_bus=self['disk_bus'],
                        device_type=self['device_type'], encryption=encryption)
```
nova.virt.libvirt.driver.LibvrirtDriver.attach_volume
```python
    def attach_volume(self, context, connection_info, instance, mountpoint,
                      disk_bus=None, device_type=None, encryption=None):

        self._connect_volume(context, connection_info, instance, encryption=encryption)
```
nova.virt.libvirt.driver.LibvrirtDriver._connect_volume
```python
    def _connect_volume(self, context, connection_info, instance,
                        encryption=None, allow_native_luks=True):
        
        # 获取 libvirt volume_driver
        vol_driver = self._get_volume_driver(connection_info)

        # 调用 libvirt volume_driver 的connect_volume 方法
        vol_driver.connect_volume(connection_info, instance)
        try:
            self._attach_encryptor(
                context, connection_info, encryption, allow_native_luks)


    def _get_volume_driver(self, connection_info):
        # 根据connection_info 中的 driver_volume_type 来获取对应的 volume_driver
        driver_type = connection_info.get('driver_volume_type')

        # 从 self.volume_drivers 中获取对应的 volume_driver
        if driver_type not in self.volume_drivers:
            raise exception.VolumeDriverNotFound(driver_type=driver_type)
        return self.volume_drivers[driver_type]

    # self.volume_drivers 初始化
    def __init__(self, virtapi, read_only=False):
        self.volume_drivers = self._get_volume_drivers()

    def _get_volume_drivers(self):
        driver_registry = dict()

        for driver_str in libvirt_volume_drivers:
            driver_type, _sep, driver = driver_str.partition('=')
            driver_class = importutils.import_class(driver)
            try:
                driver_registry[driver_type] = driver_class(self._host)
            except brick_exception.InvalidConnectorProtocol:
                LOG.debug('Unable to load volume driver %s. It is not '
                          'supported on this host.', driver)

        return driver_registry

# 这个数组配置了所有的libvirt volume_driver
libvirt_volume_drivers = [
    'iscsi=nova.virt.libvirt.volume.iscsi.LibvirtISCSIVolumeDriver',
    'rbd=nova.virt.libvirt.volume.net.LibvirtNetVolumeDriver',
    'nvmeof=nova.virt.libvirt.volume.nvme.LibvirtNVMEVolumeDriver',
]
```
看下 nova/virt/libvirt/volume/iscsi.py 中 LibvirtISCSIVolumeDriver 关键方法
```python
from os_brick import initiator # 引用 os-brick 库
from os_brick.initiator import connector # 引用 os-brick 库

class LibvirtISCSIVolumeDriver(libvirt_volume.LibvirtBaseVolumeDriver):
    """Driver to attach Network volumes to libvirt."""

    def __init__(self, host):
        super(LibvirtISCSIVolumeDriver, self).__init__(host,
                                                       is_block_dev=True)

        # 调用os-brick 的 connector.InitiatorConnector.factory 方法，赋值给 self.connector
        # 后面的connect_volume 、disconnect_volume、extend_volume 方法都是基于 self.connector 来实现的
        self.connector = connector.InitiatorConnector.factory(
            initiator.ISCSI, utils.get_root_helper(),
            use_multipath=CONF.libvirt.volume_use_multipath,
            device_scan_attempts=CONF.libvirt.num_volume_scan_tries,
            transport=self._get_transport())

    def connect_volume(self, connection_info, instance):
        """Attach the volume to instance_name."""

        LOG.debug("Calling os-brick to attach iSCSI Volume")
        device_info = self.connector.connect_volume(connection_info['data'])
        LOG.debug("Attached iSCSI volume %s", device_info)

        connection_info['data']['device_path'] = device_info['path']

```
os_brick/initiator/connector.py 中 InitiatorConnector.factory 方法
```python
class InitiatorConnector(object):

    # 工厂方法，根据不同的协议，返回不同的 connector
    @staticmethod
    def factory(protocol, root_helper, driver=None,
                use_multipath=False,
                device_scan_attempts=initiator.DEVICE_SCAN_ATTEMPTS_DEFAULT,
                arch=None,
                *args, **kwargs):
        """Build a Connector object based upon protocol and architecture."""

        # We do this instead of assigning it in the definition
        # to help mocking for unit tests
        if arch is None:
            arch = platform.machine()

        # Set the correct mapping for imports
        if sys.platform == 'win32':
            _mapping = _connector_mapping_windows
        elif arch in (initiator.S390, initiator.S390X):
            _mapping = _connector_mapping_linux_s390x
        elif arch in (initiator.PPC64, initiator.PPC64LE):
            _mapping = _connector_mapping_linux_ppc64

        else:
            _mapping = _connector_mapping_linux

        LOG.debug("Factory for %(protocol)s on %(arch)s",
                  {'protocol': protocol, 'arch': arch})
        protocol = protocol.upper()

        # set any special kwargs needed by connectors
        if protocol in (initiator.NFS, initiator.GLUSTERFS,
                        initiator.SCALITY, initiator.QUOBYTE,
                        initiator.VZSTORAGE):
            kwargs.update({'mount_type': protocol.lower()})
        elif protocol == initiator.ISER:
            kwargs.update({'transport': 'iser'})

        # now set all the default kwargs
        kwargs.update(
            {'root_helper': root_helper,
             'driver': driver,
             'use_multipath': use_multipath,
             'device_scan_attempts': device_scan_attempts,
             })

        connector = _mapping.get(protocol)
        if not connector:
            msg = (_("Invalid InitiatorConnector protocol "
                     "specified %(protocol)s") %
                   dict(protocol=protocol))
            raise exception.InvalidConnectorProtocol(msg)

        conn_cls = importutils.import_class(connector)
        return conn_cls(*args, **kwargs)

```
工厂方法根据不同的协议，返回不同的 connector，比如 ISCSI 协议返回的是 os_brick/initiator/connectors/iscsi.py 中的 ISCSIConnector 类。然后 LibvirtISCSIVolumeDriver 类的 connect_volume 方法调用的是 ISCSIConnector 类的 connect_volume 方法。
```python
    def connect_volume(self, connection_properties):

        try:
            if self.use_multipath:
                return self._connect_multipath_volume(connection_properties)
            return self._connect_single_volume(connection_properties)
        except Exception:
            # NOTE(geguileo): By doing the cleanup here we ensure we only do
            # the logins once for multipath if they succeed, but retry if they
            # don't, which helps on bad network cases.
            with excutils.save_and_reraise_exception():
                self._cleanup_connection(connection_properties, force=True)
```
所以，当开启 use_multipath 时，会调用 _connect_multipath_volume 方法，否则调用 _connect_single_volume 方法。

先看简单的 _connect_single_volume 方法
```python
    def _connect_single_volume(self, connection_properties):
        """Connect to a volume using a single path."""
        data = {'stop_connecting': False, 'num_logins': 0, 'failed_logins': 0,
                'stopped_threads': 0, 'found_devices': [],
                'just_added_devices': []}

        # 遍历所有的 target_portal、target_iqn、target_lun
        for props in self._iterate_all_targets(connection_properties):
            self._connect_vol(self.device_scan_attempts, props, data)
            found_devs = data['found_devices']
            if found_devs:
                for __ in range(10):
                    wwn = self._linuxscsi.get_sysfs_wwn(found_devs)
                    if wwn:
                        return self._get_connect_result(connection_properties,
                                                        wwn, found_devs)
                    time.sleep(1)
                LOG.debug('Could not find the WWN for %s.', found_devs[0])

            # If we failed we must cleanup the connection, as we could be
            # leaving the node entry if it's not being used by another device.
            ips_iqns_luns = ((props['target_portal'], props['target_iqn'],
                              props['target_lun']), )
            self._cleanup_connection(props, ips_iqns_luns, force=True,
                                     ignore_errors=True)
            # Reset connection result values for next try
            data.update(num_logins=0, failed_logins=0, found_devices=[])

        raise exception.VolumeDeviceNotFound(device='')
```
LibvirtISCSIVolumeDriver 会调用父类 BaseISCSIConnector 的工具方法 _iterate_all_targets 来获取所有的 target_portal、target_iqn、target_lun。我们有必要看一下这里的代码：

```python
# 返回一个生成器，每次迭代返回一个目标设备的配置字典。
def _iterate_all_targets(self, connection_properties):
    # 遍历 _get_all_targets 返回的目标设备元组列表
    for portal, iqn, lun in self._get_all_targets(connection_properties):
        # 深拷贝 connection_properties，避免修改原始字典
        props = copy.deepcopy(connection_properties)
        # 更新当前目标设备的配置
        props['target_portal'] = portal
        props['target_iqn'] = iqn
        props['target_lun'] = lun
        # 移除与多个目标设备相关的键
        for key in ('target_portals', 'target_iqns', 'target_luns'):
            props.pop(key, None)
        # 使用 yield 返回当前目标设备的配置字典
        yield props


# 如果 connection_properties 中包含 target_portals、target_iqns 和 target_luns，则返回一个 zip 对象，其中每个元素是一个三元组 (portal, iqn, lun)。
# 如果不包含上述三个键，则返回一个包含单个三元组的列表 [(portal, iqn, lun)]。
def _get_all_targets(self, connection_properties):
    # 检查 connection_properties 中是否同时包含 target_portals、target_iqns 和 target_luns 三个键
    if all([key in connection_properties for key in ('target_portals',
                                                     'target_iqns',
                                                     'target_luns')]):
        # 如果包含，将这三个列表的元素一一对应组合成元组，返回一个 zip 对象
        return zip(connection_properties['target_portals'],
                   connection_properties['target_iqns'],
                   connection_properties['target_luns'])

    # 如果不包含上述三个键，则使用 target_portal、target_iqn 和 target_lun（默认值为 0）生成单个元组
    return [(connection_properties['target_portal'],
             connection_properties['target_iqn'],
             connection_properties.get('target_lun', 0))]

# 示例1：多个目标设备
connection_properties = {
    'target_portals': ['192.168.1.1:3260', '192.168.1.2:3260'],
    'target_iqns': ['iqn.2023-01.com.example:target1', 'iqn.2023-01.com.example:target2'],
    'target_luns': [0, 1],
    'other_key': 'value'
}

for props in self._iterate_all_targets(connection_properties):
    print(props)

# 输出：
# {'target_portal': '192.168.1.1:3260', 'target_iqn': 'iqn.2023-01.com.example:target1', 'target_lun': 0, 'other_key': 'value'}
# {'target_portal': '192.168.1.2:3260', 'target_iqn': 'iqn.2023-01.com.example:target2', 'target_lun': 1, 'other_key': 'value'}

# 示例2：单个目标设备
connection_properties = {
    'target_portal': '192.168.1.1:3260',
    'target_iqn': 'iqn.2023-01.com.example:target1',
    'other_key': 'value'
}

for props in self._iterate_all_targets(connection_properties):
    print(props)

# 输出：
# {'target_portal': '192.168.1.1:3260', 'target_iqn': 'iqn.2023-01.com.example:target1', 'target_lun': 0, 'other_key': 'value'}

```
通过上述函数获得 props 后，调用 ISCSIConnector._connect_vol 方法：
```python
    def _connect_vol(self, rescans, props, data):
        device = hctl = None
        portal = props['target_portal']
        session, manual_scan = self._connect_to_iscsi_portal(props)
        do_scans = rescans > 0
        retry = 1
        if session:
            data['num_logins'] += 1
            LOG.debug('Connected to %s', portal)
            while do_scans:
                try:
                    if not hctl:
                        hctl = self._linuxscsi.get_hctl(session,
                                                        props['target_lun'])
                    # Scan is sent on connect by iscsid, so skip first rescan
                    # but on manual scan mode we have to do it ourselves.
                    if hctl:
                        if retry > 1 or manual_scan:
                            self._linuxscsi.scan_iscsi(*hctl)

                        device = self._linuxscsi.device_name_by_hctl(session,
                                                                     hctl)
                        if device:
                            break

                except Exception:
                    LOG.exception('Exception scanning %s', portal)
                    pass
                retry += 1
                do_scans = (retry <= rescans and
                            not (device or data['stop_connecting']))
                if do_scans:
                    time.sleep(retry ** 2)
            if device:
                LOG.debug('Connected to %s using %s', device,
                          strutils.mask_password(props))
            else:
                LOG.warning('LUN %(lun)s on iSCSI portal %(portal)s not found '
                            'on sysfs after logging in.',
                            {'lun': props['target_lun'], 'portal': portal})
        else:
            LOG.warning('Failed to connect to iSCSI portal %s.', portal)
            data['failed_logins'] += 1

        if device:
            data['found_devices'].append(device)
            data['just_added_devices'].append(device)
        data['stopped_threads'] += 1
```