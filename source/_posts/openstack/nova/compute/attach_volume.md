---
title:  OpenStack 虚拟机挂载数据卷过程分析
date: 2025-03-07 10:25:43
tags:
categories: OpenStack
---
# 如何把块设备挂载到虚拟机
如何把一个块设备提供给虚拟机使用，`qemu-kvm`只需要通过`--drive`参数指定即可。如果使用libvirt，以CLI `virsh`为例，可以通过`attach-device`子命令挂载设备给虚拟机使用，该命令包含两个必要参数，一个是`domain`，即虚拟机id，另一个是xml文件,文件包含设备的地址信息。

```sh
$ virsh  help attach-device
  NAME
    attach-device - attach device from an XML file

  SYNOPSIS
    attach-device <domain> <file> [--persistent] [--config] [--live] [--current]

  DESCRIPTION
    Attach device from an XML <file>.

  OPTIONS
    [--domain] <string>  domain name, id or uuid
    [--file] <string>  XML file
    --persistent     make live change persistent
    --config         affect next boot
    --live           affect running domain
    --current        affect current domain
```

iSCSI设备需要先把lun设备映射到宿主机本地，然后当做本地设备挂载即可。一个简单的demo xml为:

```xml
<disk type='block' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source dev='/dev/disk/by-path/ip-10.0.0.2:3260-iscsi-iqn.2010-10.org.openstack:volume-2ed1b04c-b34f-437d-9aa3-3feeb683d063-lun-0'/>
      <target dev='vdb' bus='virtio'/>
      <serial>2ed1b04c-b34f-437d-9aa3-3feeb683d063</serial>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
</disk>
```

可见`source`就是lun设备映射到本地的路径。

值得一提的是，libvirt支持直接挂载rbd `image`（宿主机需要包含rbd内核模块），通过rbd协议访问image，而不需要先`map`到宿主机本地，一个demo xml文件为:

```xml
<disk type='network' device='disk'>
      <driver name='qemu' type='raw' cache='writeback'/>
      <auth username='admin'>
        <secret type='ceph' uuid='bdf77f5d-bf0b-1053-5f56-cd76b32520dc'/>
      </auth>
      <source protocol='rbd' name='nova-pool/962b8560-95c3-4d2d-a77d-e91c44536759_disk'>
        <host name='10.0.0.2' port='6789'/>
        <host name='10.0.0.3' port='6789'/>
        <host name='10.0.0.4' port='6789'/>
      </source>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
</disk>
```

所以我们Cinder如果使用LVM driver，则需要先把LV加到iSCSI target中，然后映射到计算节点的宿主机，而如果使用rbd driver，不需要映射到计算节点，直接挂载即可。

以上介绍了存储的一些基础知识，有了这些知识，再去理解OpenStack nova和cinder就非常简单了，接下来我们开始进入我们的正式主题，分析OpenStack虚拟机挂载数据卷的流程。

# nova 侧代码
## VolumeAttachmentController 

- 接口一览
```python
    ('/servers/{server_id}/os-volume_attachments', {
        'GET': [server_volume_attachments_controller, 'index'], # list虚拟机挂载的卷
        'POST': [server_volume_attachments_controller, 'create'], # attach卷
    }),
    ('/servers/{server_id}/os-volume_attachments/{id}', {
        'GET': [server_volume_attachments_controller, 'show'], # show虚拟机挂载的卷
        'DELETE': [server_volume_attachments_controller, 'delete'] # detach卷
    })
```

- index 方法查询虚拟机所有挂载的卷,nova volume-attachments命令调用的是这个接口。
- 实现是查询nova数据库block_device_mapping表，这个表是nova中非常重要的一个表，很多接口的实现都和它密切相关。
- index方法并没有将bdms的所有字段返回，而是_translate_attachment_detail_view处理后，仅仅返回了几个字段。
```python
    def index(self, req, server_id):
        """Returns the list of volume attachments for a given instance."""

        bdms = objects.BlockDeviceMappingList.get_by_instance_uuid(
                context, instance.uuid)
        limited_list = common.limited(bdms, req)

        results = []
        for bdm in limited_list:
            if bdm.volume_id:
                va = _translate_attachment_detail_view(
                    bdm, show_tag=show_tag,
                    show_delete_on_termination=show_delete_on_termination)
                results.append(va)

        return {'volumeAttachments': results}
```

- show 方法的实现和index的基本一致,查询block_device_mapping表，然后_translate_attachment_detail_view处理后返回。
```python
    def show(self, req, server_id, id):
        """Return data about the given volume attachment."""

        bdm = objects.BlockDeviceMapping.get_by_volume_and_instance(
            context, volume_id, instance.uuid)

        return {'volumeAttachment': _translate_attachment_detail_view(
            bdm, show_tag=show_tag,
            show_delete_on_termination=show_delete_on_termination)}
```
- block_device_mapping 表
```sql
mysql> desc block_device_mapping;
+-----------------------+--------------+------+-----+---------+----------------+
| Field                 | Type         | Null | Key | Default | Extra          |
+-----------------------+--------------+------+-----+---------+----------------+
| created_at            | datetime     | YES  |     | NULL    |                |
| updated_at            | datetime     | YES  |     | NULL    |                |
| deleted_at            | datetime     | YES  |     | NULL    |                |
| id                    | int(11)      | NO   | PRI | NULL    | auto_increment |
| device_name           | varchar(255) | YES  |     | NULL    |                |
| delete_on_termination | tinyint(1)   | YES  |     | NULL    |                |
| snapshot_id           | varchar(36)  | YES  | MUL | NULL    |                |
| volume_id             | varchar(36)  | YES  | MUL | NULL    |                |
| volume_size           | int(11)      | YES  |     | NULL    |                |
| no_device             | tinyint(1)   | YES  |     | NULL    |                |
| connection_info       | mediumtext   | YES  |     | NULL    |                |
| instance_uuid         | varchar(36)  | YES  | MUL | NULL    |                |
| deleted               | int(11)      | YES  |     | NULL    |                |
| source_type           | varchar(255) | YES  |     | NULL    |                |
| destination_type      | varchar(255) | YES  |     | NULL    |                |
| guest_format          | varchar(255) | YES  |     | NULL    |                |
| device_type           | varchar(255) | YES  |     | NULL    |                |
| disk_bus              | varchar(255) | YES  |     | NULL    |                |
| boot_index            | int(11)      | YES  |     | NULL    |                |
| image_id              | varchar(36)  | YES  |     | NULL    |                |
| tag                   | varchar(255) | YES  |     | NULL    |                |
| attachment_id         | varchar(36)  | YES  |     | NULL    |                |
| uuid                  | varchar(36)  | YES  | UNI | NULL    |                |
| backup_id             | varchar(36)  | YES  |     | NULL    |                |
| volume_type           | varchar(255) | YES  |     | NULL    |                |
+-----------------------+--------------+------+-----+---------+----------------+
```
- create方法attach卷
- delete方法detach卷

### nova-api 挂载盘流程
- _check_volume_already_attached_to_instance() : 检查卷是否已经挂载到虚拟机,其实现也是查询block_device_mapping表,如果查询不到，说明卷没有挂载到虚拟机。
```python
        try:
            objects.BlockDeviceMapping.get_by_volume_and_instance(
                context, volume_id, instance.uuid)

            msg = _("volume %s already attached") % volume_id
            raise exception.InvalidVolume(reason=msg)
        except exception.VolumeBDMNotFound:
            pass
```
- _create_volume_bdm(): 即在`block_device_mapping`表中创建对应的记录，由于API节点无法拿到目标虚拟机挂载后的设备名，比如`/dev/vdb`，只有计算节点才知道自己虚拟机映射到哪个设备。因此bdm不是在API节点创建的，而是通过RPC请求到虚拟机所在的计算节点创建，请求方法为`reserve_block_device_name`，该方法首先调用libvirt分配一个设备名，比如`/dev/vdb`，然后创建对应的bdm实例。

```python
    def _create_volume_bdm(self, context, instance, device, volume,
                           disk_bus, device_type, is_local_creation=False,
                           tag=None, delete_on_termination=False):

            volume_bdm = self.compute_rpcapi.reserve_block_device_name(
                context, instance, device, volume_id, disk_bus=disk_bus,
                device_type=device_type, tag=tag,
                multiattach=volume['multiattach'])
            volume_bdm.delete_on_termination = delete_on_termination
            volume_bdm.save()
        return volume_bdm
```

- _check_attach_and_reserve_volume(): 调用 cinder api 创建 attachment_create 接口，然后把返回的 attachment_id 更新block_device_mapping表中。

```python
    def _check_attach_and_reserve_volume(self, context, volume, instance,
                                         bdm, supports_multiattach=False):

        attachment_id = self.volume_api.attachment_create(
            context, volume_id, instance.uuid)['id']
        bdm.attachment_id = attachment_id
```

- self.compute_rpcapi.attach_volume() : rpc 计算节点的 attach_volume()方法。

### nova-compute 挂载盘流程
- attach_volume(): 位于nova/compute/manager.py，先是调用 `driver_bdm = driver_block_device.convert_volume(bdm)` 将 bdm(dict) 对象转化成 `DriverVolumeBlockDevice` 对象, 然后调用对象的attach方法，方法位于 nova/virt/block_device.py。

- get_volume_connector()：该方法首先调用的是`virt_driver.get_volume_connector(instance)`，其中`virt_driver`这里就是`libvirt`，该方法位于`nova/virt/libvirt/driver.py`，其实就是调用os-brick的`get_connector_properties`:

```python
def get_volume_connector(self, instance):
   root_helper = utils.get_root_helper()
   return connector.get_connector_properties(
       root_helper, CONF.my_block_storage_ip,
       CONF.libvirt.iscsi_use_multipath,
       enforce_multipath=True,
       host=CONF.host)
```

os-brick是从Cinder项目分离出来的，专门用于管理各种存储系统卷的库，代码仓库为[os-brick](https://github.com/openstack/os-brick)。其中`get_connector_properties`方法位于`os_brick/initiator/connector.py`:
```python
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
该方法最重要的工作就是返回该计算节点的信息（如ip、操作系统类型等)以及initiator name(参考第2节内容)。

- volume_api.initialize_connection(): 调用Cinder API的`initialize_connection`方法，返回 connection_info:
```python
    def _legacy_volume_attach(self, context, volume, connector, instance,
                              volume_api, virt_driver,
                              do_driver_attach=False):

        connection_info = volume_api.initialize_connection(context,
                                                           volume_id,
                                                         connector)
'''connection_info数结构如下所示
{
    'driver_volume_type': 'iscsi',
    'data': {
        'auth_password': 'YZ2Hceyh7VySh5HY',
        'target_discovered': False,
        'encrypted': False,
        'qos_specs': None,
        'target_iqn': 'iqn.2010-10.org.openstack:volume-8b1ec3fe-8c57-45ca-a1cf-a481bfc8fce2',
        'target_portal': '11.0.0.8:3260',
        'volume_id': '8b1ec3fe-8c57-45ca-a1cf-a481bfc8fce2',
        'target_lun': 1,
        'access_mode': 'rw',
        'auth_username': 'nE9PY8juynmmZ95F7Xb7',
        'auth_method': 'CHAP'
    }
}'''                                               
```





- `virt_driver.attach_volume()` ：此时到达libvirt层，代码位于`nova/virt/libvirt/driver.py`，该方法分为如下几个步骤：
- `_connect_volume()`

该方法会调用`nova/virt/libvirt/volume/iscsi.py`的`connect_volume()`方法，该方法其实是直接调用os-brick的`connect_volume()`方法，该方法位于`os_brick/initiator/connector.py`中`ISCSIConnector`类中的`connect_volume`方法，该方法会调用前面介绍的`iscsiadm`命令的`discovory`以及`login`子命令，即把lun设备映射到本地设备。

- `_get_volume_config()`

获取`volume`的信息，其实也就是我们生成xml需要的信息，最重要的就是拿到映射后的本地设备的路径，如`/dev/disk/by-path/ip-10.0.0.2:3260-iscsi-iqn.2010-10.org.openstack:volume-060fe764-c17b-45da-af6d-868c1f5e19df-lun-0`,返回的conf最终会转化成xml格式。该代码位于`nova/virt/libvirt/volume/iscsi.py`：

```python
def get_config(self, connection_info, disk_info):
    """Returns xml for libvirt."""
    conf = super(LibvirtISCSIVolumeDriver,
                 self).get_config(connection_info, disk_info)
    conf.source_type = "block"
    conf.source_path = connection_info['data']['device_path']
    conf.driver_io = "native"
    return conf
```
终于到了最后一步，该步骤其实就类似于调用`virsh attach-device`命令把设备挂载到虚拟机中，该代码位于`nova/virt/libvirt/guest.py`：

```python
def attach_device(self, conf, persistent=False, live=False):
   """Attaches device to the guest.

   :param conf: A LibvirtConfigObject of the device to attach
   :param persistent: A bool to indicate whether the change is
                      persistent or not
   :param live: A bool to indicate whether it affect the guest
                in running state
   """
   flags = persistent and libvirt.VIR_DOMAIN_AFFECT_CONFIG or 0
   flags |= live and libvirt.VIR_DOMAIN_AFFECT_LIVE or 0
   self._domain.attachDeviceFlags(conf.to_xml(), flags=flags)
```

libvirt的工作完成，此时volume已经挂载到虚拟机中了。

- `volume_api.attach()`

回到`nova/virt/block_device.py`，最后调用了`volume_api.attach()`方法，该方法向Cinder发起API请求。此时cinder-api通过RPC请求到`cinder-volume`，代码位于`cinder/volume/manager.py`，该方法没有做什么工作，其实就是更新数据库，把volume状态改为`in-use`。


# cinder 侧代码
## attachments.create

在nova中，`volume_api.initialize_connection()`调用Cinder API的initialize_connection方法。该方法又会RPC请求给volume所在的`cinder-volume`服务节点。代码位置为`cinder/volume/manager.py`，该方法也是分阶段的。

- driver.validate_connector()

该方法不同的driver不一样，对于LVM + iSCSI来说，就是检查有没有`initiator`字段，即nova-compute节点的initiator信息

```python
def validate_connector(self, connector):

   if 'initiator' not in connector:
       err_msg = (_LE('The volume driver requires the iSCSI initiator '
                      'name in the connector.'))
       LOG.error(err_msg)
       raise exception.InvalidConnectorException(missing='initiator')
   return True
```

- `driver.create_export()`: 该方法位于`cinder/volume/targets/iscsi.py`:

```python
def create_export(self, context, volume, volume_path):
    # 'iscsi_name': 'iqn.2010-10.org.openstack:volume-00000001'
    iscsi_name = "%s%s" % (self.configuration.iscsi_target_prefix,
                           volume['name'])
    iscsi_target, lun = self._get_target_and_lun(context, volume)
    chap_auth = self._get_target_chap_auth(context, iscsi_name)
    if not chap_auth:
        chap_auth = (vutils.generate_username(),
                     vutils.generate_password())

    # Get portals ips and port
    portals_config = self._get_portals_config()
    tid = self.create_iscsi_target(iscsi_name,
                                   iscsi_target,
                                   lun,
                                   volume_path,
                                   chap_auth,
                                   **portals_config)
    data = {}
    data['location'] = self._iscsi_location(
        self.configuration.iscsi_ip_address, tid, iscsi_name, lun,
        self.configuration.iscsi_secondary_ip_addresses)
    LOG.debug('Set provider_location to: %s', data['location'])
    data['auth'] = self._iscsi_authentication(
        'CHAP', *chap_auth)
    return data
```

该方法最重要的操作是调用了create_iscsi_target方法, create_iscsi_target方法通过写入配置文件的方法创建target。

- create_iscsi_target(): 该方法位于`cinder/volume/targets/tgt.py`:
```python
class TgtAdm(iscsi.ISCSITarget):
    # target 配置文件模板
    VOLUME_CONF = textwrap.dedent("""
                <target %(name)s>
                    backing-store %(path)s
                    driver %(driver)s
                    %(chap_auth)s
                    %(target_flags)s
                    write-cache %(write_cache)s
                </target>
                  """)

    def create_iscsi_target(self, name, tid, lun, path,
                            chap_auth=None, **kwargs):
        # 渲染配置文件模板
        volume_conf = self.VOLUME_CONF % {
            'name': name, 'path': path, 'driver': driver,
            'chap_auth': chap_str, 'target_flags': target_flags,
            'write_cache': write_cache}

        LOG.debug('Creating iscsi_target for Volume ID: %s', vol_id)
        volumes_dir = self.volumes_dir
        volume_path = os.path.join(volumes_dir, vol_id)

        # 写入配置文件
        utils.robust_file_write(volumes_dir, vol_id, volume_conf)
```

- `driver.initialize_connection()`：返回connection_info，该方法位于`cinder/volume/drivers/iscsi.py`:
```python
    def initialize_connection(self, volume, connector):
        """Initializes the connection and returns connection info.

        The iscsi driver returns a driver_volume_type of 'iscsi'.
        The format of the driver data is defined in _get_iscsi_properties.
        Example return value::
            {
                'driver_volume_type': 'iscsi',
                'data': {
                    'auth_password': 'YZ2Hceyh7VySh5HY',
                    'target_discovered': False,
                    'encrypted': False,
                    'qos_specs': None,
                    'target_iqn': 'iqn.2010-10.org.openstack:volume-8b1ec3fe-8c57-45ca-a1cf-a481bfc8fce2',
                    'target_portal': '11.0.0.8:3260',
                    'volume_id': '8b1ec3fe-8c57-45ca-a1cf-a481bfc8fce2',
                    'target_lun': 1,
                    'access_mode': 'rw',
                    'auth_username': 'nE9PY8juynmmZ95F7Xb7',
                    'auth_method': 'CHAP'
                }
            }
        """

        iscsi_properties = self._get_iscsi_properties(volume,
                                                      connector.get(
                                                          'multipath'))
        return {
            'driver_volume_type': self.iscsi_protocol,
            'data': iscsi_properties
        }
```