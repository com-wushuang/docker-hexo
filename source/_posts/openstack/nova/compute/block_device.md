---
title:  nova 创建虚机时的块设备处理
date: 2023-03-28 15:18:17
tags:
categories: OpenStack
---

### nova-api 侧的块设备参数
`nova-api`侧参数如下例子：
```json
# POST /servers
{
    "block_device_mapping_v2": [{
        "boot_index": "0",
        "uuid": "ac408821-c95a-448f-9292-73986c790911",
        "source_type": "image",
        "volume_size": "25",
        "destination_type": "volume",
        "delete_on_termination": true,
        "tag": "disk1",
        "disk_bus": "scsi",
        "guest_format": "ext2"
    }]
}
```
- `source_type`表示待创建的块设备的初始数据来源，这一般用于将系统镜像数据拷贝到具体新块设备中，如果不需要数据，则标记类型为blank，创建一块空白块设备；
- `destination_type`只支持volume和local两种形式。volume表示块设备由cinder提供，local表示通过计算节点（hypervisor所在节点）开辟一块空间提供。
### 块设备分类
- 由于源类型(image,snapshot,volume,blank)有这么几种可选
- 目的类型（volume,local）有这两种可选
- 上面参数可以组合出几种形态，依据不同的形态有不同的含义：


| dest type | source type | 说明                                                         |
| --------- | ----------- | ------------------------------------------------------------ |
| volume    | volume      | 可直接挂载到虚拟机中。当 boot_index = 0， 相当于boot from volume |
|           | snapshot    | 调用 cinder 依据快照创建新卷，并挂载到虚拟机中。当 boot_index = 0， 相当于boot from snapshot |
|           | image       | 调用cinder依据镜像创建新卷，将glance image的数据拷贝到新建卷中（由cinder访问glance完成），然后挂载到虚拟机中。当 boot_index = 0， 相当于boot from image |
|           | blank       | 调用cinder依大小创建一个空卷并挂载到虚拟机中                 |
| local     | image       | 在计算节点特定位置创建 ephemeral 分区，将 glance 的image 数据拷贝新建的分区中，并启动虚拟机 |
|           | blank       | guest_format=swap 时，创建 swap 分区，否则创建 ephemeral  分区，并挂载到虚拟机中 |

### 数据表
- 在 `nova` 的数据表中有 `block_device_mapping`
- `conduct` 在 `build_instance` 的块信息数据就是从这张表查询出来的。
```sql
nova@mariadb.cty.os 14:11:  [nova]> select * from block_device_mapping where instance_uuid ='55888641-5569-4d50-a6c3-eeb8f6d51c34' \G;
*************************** 1. row ***************************
           created_at: 2023-03-23 02:48:39
           updated_at: 2023-03-23 02:48:45
           deleted_at: NULL
                   id: 143
          device_name: /dev/vda
delete_on_termination: 1
          snapshot_id: NULL
            volume_id: 9a53945a-b745-493e-8710-0f2c92e1fb5f
          volume_size: 100
            no_device: 0
      connection_info: {"driver_volume_type": "rbd", "connector": {"platform": "x86_64", "host": "ytj-kvm-10e101e8e12", "do_local_attach": false, "ip": "10.101.8.12", "os_type": "linux2", "multipath": false, "initiator": "iqn.2012-01.com.openeuler:6a8eeeadc98"}, "serial": "9a53945a-b745-493e-8710-0f2c92e1fb5f", "data": {"secret_type": "ceph", "name": "volumes/volume-9a53945a-b745-493e-8710-0f2c92e1fb5f", "encrypted": false, "discard": true, "keyring": "[client.cinder]\n\tkey = AQBjifhjdv+0ORAAFWZTU30onDsqcmEJoNz+Tg==\n", "cluster_name": "ceph", "secret_uuid": "817cf80b-d3c5-47b2-9a70-aa578e539107", "qos_specs": null, "auth_enabled": true, "volume_id": "9a53945a-b745-493e-8710-0f2c92e1fb5f", "hosts": ["10.101.24.27", "10.101.24.28", "10.101.24.29"], "access_mode": "rw", "auth_username": "cinder", "ports": ["6789", "6789", "6789"]}}
        instance_uuid: 55888641-5569-4d50-a6c3-eeb8f6d51c34
              deleted: 0
          source_type: image
     destination_type: volume
         guest_format: NULL
          device_type: disk
             disk_bus: virtio
           boot_index: 0
             image_id: dbbec6ed-017e-45b0-845d-45c73c718ac6
                  tag: NULL
        attachment_id: NULL
                 uuid: cbe90cc3-c7fb-4fab-bd6e-72bbc87867c8
            backup_id: NULL
          volume_type: SAS-public
*************************** 2. row ***************************
           created_at: 2023-03-23 02:48:57
           updated_at: 2023-03-23 02:48:59
           deleted_at: NULL
                   id: 146
          device_name: /dev/vdb
delete_on_termination: 0
          snapshot_id: NULL
            volume_id: 56494430-5460-4582-a3d0-e22cb4ef0cd2
          volume_size: 500
            no_device: NULL
      connection_info: {"status": "reserved", "detached_at": "", "volume_id": "56494430-5460-4582-a3d0-e22cb4ef0cd2", "attach_mode": null, "driver_volume_type": "rbd", "instance": "55888641-5569-4d50-a6c3-eeb8f6d51c34", "attached_at": "", "serial": "56494430-5460-4582-a3d0-e22cb4ef0cd2", "data": {"secret_type": "ceph", "name": "volumes/volume-56494430-5460-4582-a3d0-e22cb4ef0cd2", "encrypted": false, "discard": true, "keyring": "[client.cinder]\n\tkey = AQBjifhjdv+0ORAAFWZTU30onDsqcmEJoNz+Tg==\n", "cluster_name": "ceph", "secret_uuid": "817cf80b-d3c5-47b2-9a70-aa578e539107", "qos_specs": null, "auth_enabled": true, "volume_id": "56494430-5460-4582-a3d0-e22cb4ef0cd2", "hosts": ["10.101.24.27", "10.101.24.28", "10.101.24.29"], "access_mode": "rw", "auth_username": "cinder", "ports": ["6789", "6789", "6789"]}}
        instance_uuid: 55888641-5569-4d50-a6c3-eeb8f6d51c34
              deleted: 0
          source_type: volume
     destination_type: volume
         guest_format: NULL
          device_type: NULL
             disk_bus: NULL
           boot_index: NULL
             image_id: NULL
                  tag: NULL
        attachment_id: a0c38bca-1aff-4cf5-b25d-88b3d013d01d
                 uuid: 0b3f4fca-30d6-4262-ac44-482a6eea7f14
            backup_id: NULL
          volume_type: NULL
2 rows in set (0.00 sec)

```

### conductor
```python
# 数据库中查询参数
bdms = objects.BlockDeviceMappingList.get_by_instance_uuid(
        context, instance.uuid)

# 参数被用在此处
self.compute_rpcapi.build_and_run_instance(context,
        instance=instance, host=host.service_host, image=image,
        request_spec=local_reqspec,
        filter_properties=local_filter_props,
        admin_password=admin_password,
        injected_files=injected_files,
        requested_networks=requested_networks,
        security_groups=security_groups,
        block_device_mapping=bdms, node=host.nodename,
        limits=host.limits, host_list=host_list)
```
### nova-compute
- nova compute 服务处理虚拟机块设备都主要集中在`_prep_block_device`函数中：
```python
    def _prep_block_device(self, context, instance, bdms):
        """Set up the block device for an instance with error logging."""
        try:
            self._add_missing_dev_names(bdms, instance)

            # 前文conductor查询出数据库中的 bdms 信息
            # 然后这里将数据库类型的 bdms 封装成对应的blockdevice类
            block_device_info = driver.get_block_device_info(instance, bdms)
            mapping = driver.block_device_info_get_mapping(block_device_info)

            multidisks = driver.block_device_info_get_local_disks(
                block_device_info)
            self._recheck_bare_disks_occupation_status(multidisks)

            driver_block_device.attach_block_devices(
                mapping, context, instance, self.volume_api, self.driver,
                wait_func=self._await_block_device_map_created)
            self._check_instance_backups(context, instance, mapping)

            self._block_device_info_to_legacy(block_device_info)
            return block_device_info

        except exception.OverQuota as e:
        # 省略多行
```
- 将数据库类型的 bdms 封装成对应的 blockdevice 类
```python
def get_block_device_info(instance, block_device_mapping):
    from nova.virt import block_device as virt_block_device

    block_device_info = {
        'root_device_name': instance.root_device_name,
        'ephemerals': virt_block_device.convert_ephemerals(
            block_device_mapping),
        'block_device_mapping':
            # 关键方法
            virt_block_device.convert_all_volumes(*block_device_mapping),
        'local_disks': virt_block_device.convert_local_disks(
            block_device_mapping)
    }
    swap_list = virt_block_device.convert_swap(block_device_mapping)
    block_device_info['swap'] = virt_block_device.get_swap(swap_list)

    return block_device_info
```
- 这里我们重点关注下 `convert_all_volumes` 这个方法,就是依次判断每个磁盘的类型，然后返回对应的对象
```python
# 主调函数
def convert_all_volumes(*volume_bdms):
    source_volume = convert_volumes(volume_bdms)
    source_snapshot = convert_snapshots(volume_bdms)
    source_image = convert_images(volume_bdms)
    source_blank = convert_blanks(volume_bdms)
    source_backup = convert_backups(volume_bdms)

    return [vol for vol in
            itertools.chain(source_volume, source_snapshot,
                            source_image, source_blank, source_backup)]

# 偏函数 
convert_volumes = functools.partial(_convert_block_devices,
                                   DriverVolumeBlockDevice)

# 转换主逻辑
def _convert_block_devices(device_type, block_device_mapping):
    devices = []
    for bdm in block_device_mapping:
        try:
            # 直接初始化对象调用 __ini__ 方法，后面会讲到
            devices.append(device_type(bdm))
        
        # 如果类型不符合，则pass
        # _InvalidType 继承了_NotTransformable
        except _NotTransformable:
            pass

    return devices
```
- `device_type` 类型有多种，他们的继承关系如下：
![blockdevice_class](https://raw.githubusercontent.com/com-wushuang/pics/main/blockdevice_class.png)
- 所有的类初始化，都会调用 `DriveBlockDevice` 的 `init` 方法
```python
    def __init__(self, bdm):
        self.__dict__['_bdm_obj'] = bdm

        if self._bdm_obj.no_device:
            raise _NotTransformable()

        self.update({field: None for field in self._fields})
        self._transform()
```
- `init` 方法最后会调用一下 `_transform`方法，其中一个实现如下：
```python
    def _transform(self):
        if (not self._bdm_obj.source_type == self._valid_source
                or not self._bdm_obj.destination_type ==
                self._valid_destination):
            raise _InvalidType

        self.update(
            {k: v for k, v in self._bdm_obj.items()
             if k in self._new_fields | set(['delete_on_termination'])}
        )
        self['mount_device'] = self._bdm_obj.device_name
        try:
            self['connection_info'] = jsonutils.loads(
                self._bdm_obj.connection_info)
        except TypeError:
            self['connection_info'] = None
```
- 类和 `bdms` 对应关系图，注意有些 `bdms` 是没有对应的类的
![blockdevice_class2](https://raw.githubusercontent.com/com-wushuang/pics/main/blockdevice_class2.png)

- 然后循环 block_device_mapping（列表） 中的类，根据不同的类去调用其 `attach` 方法，不同的 `attach` 有不同的逻辑
```python
def attach_block_devices(block_device_mapping, *attach_args, **attach_kwargs):
    def _log_and_attach(bdm):
        instance = attach_args[1]
        if bdm.get('volume_id'):
            LOG.info('Booting with volume %(volume_id)s at '
                     '%(mountpoint)s',
                     {'volume_id': bdm.volume_id,
                      'mountpoint': bdm['mount_device']},
                     instance=instance)
        elif bdm.get('snapshot_id'):
            LOG.info('Booting with volume snapshot %(snapshot_id)s at '
                     '%(mountpoint)s',
                     {'snapshot_id': bdm.snapshot_id,
                      'mountpoint': bdm['mount_device']},
                     instance=instance)
        elif bdm.get('backup_id'):
            LOG.info('Booting with volume backup %(backup_id)s at '
                     '%(mountpoint)s',
                     {'backup_id': bdm.backup_id,
                      'mountpoint': bdm['mount_device']},
                     instance=instance)
        elif bdm.get('image_id'):
            LOG.info('Booting with volume-backed-image %(image_id)s at '
                     '%(mountpoint)s',
                     {'image_id': bdm.image_id,
                      'mountpoint': bdm['mount_device']},
                     instance=instance)
        else:
            LOG.info('Booting with blank volume at %(mountpoint)s',
                     {'mountpoint': bdm['mount_device']},
                     instance=instance)
        # 关键方法
        bdm.attach(*attach_args, **attach_kwargs)

    for device in block_device_mapping:
        _log_and_attach(device)
    return block_device_mapping
```

### 不同 attach 方法解析
- `DriverVolImageBlockDevice`：基于镜像启动虚机就是这个类型
```python
class DriverVolImageBlockDevice( ):

    _valid_source = 'image'
    _proxy_as_attr_inherited = set(['image_id'])

    def attach(self, context, instance, volume_api,
               virt_driver, wait_func=None):
        if not self.volume_id: # 如果 volume 不存在先调用 cinder-api 基于 image 创建一个 volume
            vol = self._create_volume(
                context, instance, volume_api, self.volume_size,
                wait_func=wait_func, image_id=self.image_id)

            self.volume_id = vol['id']

            # TODO(mriedem): Create an attachment to reserve the volume and
            # make us go down the new-style attach flow.

        # 创建成功后，attach 和 DriverVolumeBlockDevice 一样了，直接调用父类方法
        super(DriverVolImageBlockDevice, self).attach(
            context, instance, volume_api, virt_driver)
```
- `DriverVolumeBlockDevice`: 
    - 1.从volume启动虚机（启动盘） 
    - 2.在启动时就给虚机附加一块volume（数据盘）

这两种情况都是这种类型。
```python
class DriverVolumeBlockDevice(DriverBlockDevice):
    @update_db
    def attach(self, context, instance, volume_api, virt_driver,
               do_driver_attach=False, **kwargs):
        volume = self._get_volume(context, volume_api, self.volume_id)
        volume_api.check_availability_zone(context, volume,
                                           instance=instance)
        # Check to see if we need to lock based on the shared_targets value.
        # Default to False if the volume does not expose that value to maintain
        # legacy behavior.
        if volume.get('shared_targets', False):
            # Lock the attach call using the provided service_uuid.
            @utils.synchronized(volume['service_uuid'])
            def _do_locked_attach(*args, **_kwargs):
                self._do_attach(*args, **_kwargs)

            _do_locked_attach(context, instance, volume, volume_api,
                              virt_driver, do_driver_attach)
        else:
            # 因为volume已存在的，所以直接调用 libvirt 接口 attach 到虚机
            # We don't need to (or don't know if we need to) lock.
            self._do_attach(context, instance, volume, volume_api,
                            virt_driver, do_driver_attach)
```
- `DriverVolSnapshotBlockDevice`: 从快照启动虚机就是这种类型
```python
class DriverVolSnapshotBlockDevice(DriverVolumeBlockDevice):

    _valid_source = 'snapshot'
    _proxy_as_attr_inherited = set(['snapshot_id'])

    def attach(self, context, instance, volume_api,
               virt_driver, wait_func=None):

        if not self.volume_id:
            # 先通过 snapshot_id 查询 snapshot
            snapshot = volume_api.get_snapshot(context,
                                               self.snapshot_id)
            # NOTE(lyarwood): Try to use the original volume type if one isn't
            # set against the bdm but is on the original volume.
            if not self.volume_type and snapshot.get('volume_id'):
                snap_volume_id = snapshot.get('volume_id')
                orig_volume = volume_api.get(context, snap_volume_id)
                self.volume_type = orig_volume.get('volume_type_id')

            # 基于 snapshot 创建新 volume
            vol = self._create_volume(
                context, instance, volume_api, self.volume_size,
                wait_func=wait_func, snapshot=snapshot)

            self.volume_id = vol['id']

            # TODO(mriedem): Create an attachment to reserve the volume and
            # make us go down the new-style attach flow.
        
        # 创建完成后 attach volume
        # Call the volume attach now
        super(DriverVolSnapshotBlockDevice, self).attach(
            context, instance, volume_api, virt_driver)
```
### _do_attach 实现解析


###  日志分析
1、开始进行虚拟机的块设备处理
```log
nova.compute.manager  [instance: 55888641-5569-4d50-a6c3-eeb8f6d51c34] Start building block device mappings for instance. _build_resources /usr/lib/python2.7/site-packages/nova/compute/manager.py:2511
```
2、识别出块设备类型之后，和cinder-api进行交互，创建volume
```log
nova.virt.block_device  [instance: 55888641-5569-4d50-a6c3-eeb8f6d51c34] Booting with blank volume at /dev/vda
cinderclient.v3.client  REQ: curl -g -i -X POST http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes -H "User-Agent: python-cinderclient" -H "Content-Type: application/json" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" -d '{"volume": {"count": null, "status": "creating", "backup_id": null, "user_id": "7e4b96b1d39e4f36b9fcdbe210017b2b", "name": "", "imageRef": "dbbec6ed-017e-45b0-845d-45c73c718ac6", "availability_zone": null, "description": "", "multiattach": false, "attach_status": "detached", "volume_type": "SAS-public", "metadata": {}, "consistencygroup_id": null, "source_volid": null, "snapshot_id": null, "project_id": "9a34fcaba05b4f60a5ab71c5709338f0", "source_replica": null, "size": 100}}' _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [202] X-Compute-Request-Id: req-41f3ed96-b53f-419a-80b7-f97686bb27d4 Content-Type: application/json Content-Length: 812 Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-41f3ed96-b53f-419a-80b7-f97686bb27d4 Date: Thu, 23 Mar 2023 02:48:41 GMT
cinderclient.v3.client  POST call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes used request id req-41f3ed96-b53f-419a-80b7-f97686bb27d4 request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
cinderclient.v3.client  REQ: curl -g -i -X GET http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f -H "User-Agent: python-cinderclient" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [200] X-Compute-Request-Id: req-7741e97d-6b69-4b96-b1ba-25ad2b833bba Content-Type: application/json Content-Length: 880 Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-7741e97d-6b69-4b96-b1ba-25ad2b833bba Date: Thu, 23 Mar 2023 02:48:41 GMT
cinderclient.v3.client  GET call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f used request id req-7741e97d-6b69-4b96-b1ba-25ad2b833bba request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
cinderclient.v3.client  REQ: curl -g -i -X GET http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f -H "User-Agent: python-cinderclient" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [200] X-Compute-Request-Id: req-31869197-7996-41b8-b798-f2711de15358 Content-Type: application/json Content-Length: 880 Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-31869197-7996-41b8-b798-f2711de15358 Date: Thu, 23 Mar 2023 02:48:41 GMT
cinderclient.v3.client  GET call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f used request id req-31869197-7996-41b8-b798-f2711de15358 request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
cinderclient.v3.client  REQ: curl -g -i -X GET http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f -H "User-Agent: python-cinderclient" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [200] X-Compute-Request-Id: req-a1e0c6a1-14e6-42de-a3a5-ce8486ceddfe Content-Type: application/json Content-Length: 1366 Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-a1e0c6a1-14e6-42de-a3a5-ce8486ceddfe Date: Thu, 23 Mar 2023 02:48:44 GMT
cinderclient.v3.client  GET call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f used request id req-a1e0c6a1-14e6-42de-a3a5-ce8486ceddfe request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
cinderclient.v3.client  REQ: curl -g -i -X GET http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f -H "OpenStack-API-Version: volume 3.48" -H "User-Agent: python-cinderclient" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [200] X-Compute-Request-Id: req-d0300d35-89fc-44c8-a3c0-64039aaa45a0 Content-Type: application/json Content-Length: 1464 Openstack-Api-Version: volume 3.48 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-d0300d35-89fc-44c8-a3c0-64039aaa45a0 Date: Thu, 23 Mar 2023 02:48:44 GMT
cinderclient.v3.client  GET call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f used request id req-d0300d35-89fc-44c8-a3c0-64039aaa45a0 request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
```
3、同步的去attach_volume
```log
oslo_concurrency.lockutils  Lock "e2818631-e7f7-48f5-a8f0-77b31d393e51" acquired by "nova.virt.block_device._do_locked_attach" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
os_brick.utils  ==> get_connector_properties: call u"{'execute': None, 'my_ip': '10.101.8.12', 'enforce_multipath': True, 'host': 'ytj-kvm-10e101e8e12', 'root_helper': 'sudo nova-rootwrap /etc/nova/rootwrap.conf', 'multipath': False}" trace_logging_wrapper /usr/lib/python2.7/site-packages/os_brick/utils.py:146
os_brick.initiator.linuxfc  No Fibre Channel support detected on system. get_fc_hbas /usr/lib/python2.7/site-packages/os_brick/initiator/linuxfc.py:106
os_brick.initiator.linuxfc  No Fibre Channel support detected on system. get_fc_hbas /usr/lib/python2.7/site-packages/os_brick/initiator/linuxfc.py:106
os_brick.utils  <== get_connector_properties: return (90ms) {'initiator': u'iqn.2012-01.com.openeuler:6a8eeeadc98', 'ip': u'10.101.8.12', 'platform': u'x86_64', 'host': u'ytj-kvm-10e101e8e12', 'do_local_attach': False, 'os_type': u'linux2', 'multipath': False} trace_logging_wrapper /usr/lib/python2.7/site-packages/os_brick/utils.py:170
cinderclient.v3.client  REQ: curl -g -i -X POST http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f/action -H "User-Agent: python-cinderclient" -H "Content-Type: application/json" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" -d '{"os-initialize_connection": {"connector": {"platform": "x86_64", "host": "ytj-kvm-10e101e8e12", "do_local_attach": false, "ip": "10.101.8.12", "os_type": "linux2", "multipath": false, "initiator": "iqn.2012-01.com.openeuler:6a8eeeadc98"}}}' _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [200] X-Compute-Request-Id: req-de64b590-ddd1-4ea0-93ec-fc2dd2c40cd2 Content-Type: application/json Content-Length: 580 Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-de64b590-ddd1-4ea0-93ec-fc2dd2c40cd2 Date: Thu, 23 Mar 2023 02:48:45 GMT
cinderclient.v3.client  POST call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f/action used request id req-de64b590-ddd1-4ea0-93ec-fc2dd2c40cd2 request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
cinderclient.v3.client  REQ: curl -g -i -X POST http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f/action -H "User-Agent: python-cinderclient" -H "Content-Type: application/json" -H "X-OpenStack-Request-ID: req-55505a2c-b8c6-479c-943f-44351272a7e4" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}1ee79e0dd584e005bb365e5f03078bb9079b2657" -d '{"os-attach": {"instance_uuid": "55888641-5569-4d50-a6c3-eeb8f6d51c34", "mountpoint": "/dev/vda", "mode": "rw"}}' _http_log_request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:372
cinderclient.v3.client  RESP: [202] Content-Length: 0 X-Compute-Request-Id: req-2855aaf8-f63c-4b9d-b53d-882f20e04af1 Content-Type: application/json Openstack-Api-Version: volume 3.0 Vary: OpenStack-API-Version X-Openstack-Request-Id: req-2855aaf8-f63c-4b9d-b53d-882f20e04af1 Date: Thu, 23 Mar 2023 02:48:45 GMT _http_log_response /usr/lib/python2.7/site-packages/keystoneauth1/session.py:419
cinderclient.v3.client  POST call to cinderv3 for http://cinder-api.cty.os:10014/v3/9a34fcaba05b4f60a5ab71c5709338f0/volumes/9a53945a-b745-493e-8710-0f2c92e1fb5f/action used request id req-2855aaf8-f63c-4b9d-b53d-882f20e04af1 request /usr/lib/python2.7/site-packages/keystoneauth1/session.py:722
oslo_concurrency.lockutils  Lock "e2818631-e7f7-48f5-a8f0-77b31d393e51" released by "nova.virt.block_device._do_locked_attach" :: held 0.866s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
```