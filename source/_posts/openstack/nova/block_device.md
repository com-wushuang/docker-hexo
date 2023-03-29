---
title:  nova 创建虚机时的块设备处理
date: 2023-03-28 15:18:17
tags:
categories: OpenStack
---

### nova boot 块设备参数
nova boot(CLI) 关于块设备的参数有三个 `block_device_mapping`、`block_device_mapping_v2`、`block_device`。看了很多网上的文章，一直没搞懂，直到我打开了代码，真的太清晰了。代码逻辑用人类的语言表述，还是有失真的，想起了那一句话，信息在传递的过程中是有衰减和失真的，况且这还是在两种系统之间的传递（python和人类语言），然后我想起了那一句话，no bb show me your code！

#### 1、block_device_mapping

- `openstack` 抄袭 `EC2` 后的产物
- 代码路径:`novaclient/v2/shell.py::_boot`
- 参数样例：`--block-device-mapping vdc=818f15ec-3c5d-4791-b72e-528f82e97584:::0`
- 参数说明：`<dev-name>=<id>:<type>:<size(GB)>:<delete-on-terminate>`
```python
    # 把list类型转成dict类型
    block_device_mapping = {}
    for bdm in args.block_device_mapping:
        # 按照固定的格式分割
        device_name, mapping = bdm.split('=', 1)
        # 以device name 为 key
        block_device_mapping[device_name] = mapping
```
#### 2、block_device_mapping_v2
- `block_device_mapping` 的 `v2` 版本
- `block_device_mapping` 和 `block_device_mapping_v2` 只能有一个出现在参数列表中
- `block_device` 会转变成 `block_device_mapping_v2`中的项
- `block_device` 格式：
```
id=UUID(image_id,snapshot_id,volume_id)
souce=源类型(image,snapshot,volume,blank)
dest=目的类型（volume,local）
bus=总线类型（uml,lxc,virtio等，常用virtio）
type=设备类型（disk,cdrom,Floppy,Flash,默认是disk）
device=设备名称（vda,xda）
size=块大小
format=格式（ext4，ISO,swap,ntfs）
bootindex=定义启动盘，是启动盘的话需要是０
shutdown=关机对应动作（prserve,remove）
```
- 代码如下：
```python
block_device_mapping_v2 = _parse_block_device_mapping_v2(cs, args, image)

def _parse_block_device_mapping_v2(cs, args, image):
    bdm = []

    # boot_volume 转化成 block_device_mapping_v2 的项
    if args.boot_volume:
        bdm_dict = {'uuid': args.boot_volume, 'source_type': 'volume',
                    'destination_type': 'volume', 'boot_index': 0,
                    'delete_on_termination': False}
        bdm.append(bdm_dict)

    # snapshot 转化成 block_device_mapping_v2 的项
    if args.snapshot:
        bdm_dict = {'uuid': args.snapshot, 'source_type': 'snapshot',
                    'destination_type': 'volume', 'boot_index': 0,
                    'delete_on_termination': False}
        bdm.append(bdm_dict)

    # 处理 block_device 参数，也把他们转化成 block_device_mapping_v2 的项
    for device_spec in args.block_device:
        spec_dict = _parse_device_spec(device_spec)
        bdm_dict = {}

        if ('tag' in spec_dict and not _supports_block_device_tags(cs)):
            raise exceptions.CommandError(
                _("'tag' in block device mapping is not supported "
                  "in API version %(version)s.")
                % {'version': cs.api_version.get_string()})

        for key, value in spec_dict.items():
            bdm_dict[CLIENT_BDM2_KEYS[key]] = value

        source_type = bdm_dict.get('source_type')
        if not source_type:
            bdm_dict['source_type'] = 'blank'
        elif source_type not in (
                'volume', 'image', 'snapshot', 'blank', 'backup'):
            raise exceptions.CommandError(
                _("The value of source_type key of --block-device "
                  "should be one of 'volume', 'image', 'snapshot' "
                  "or 'blank' but it was '%(action)s'")
                % {'action': source_type})

        destination_type = bdm_dict.get('destination_type')
        if not destination_type:
            source_type = bdm_dict['source_type']
            if source_type in ('image', 'blank'):
                bdm_dict['destination_type'] = 'local'
            if source_type in ('snapshot', 'volume'):
                bdm_dict['destination_type'] = 'volume'
        elif destination_type not in ('local', 'volume'):
            raise exceptions.CommandError(
                _("The value of destination_type key of --block-device "
                  "should be either 'local' or 'volume' but it "
                  "was '%(action)s'")
                % {'action': destination_type})

        # Convert the delete_on_termination to a boolean or set it to true by
        # default for local block devices when not specified.
        if 'delete_on_termination' in bdm_dict:
            action = bdm_dict['delete_on_termination']
            if action not in ['remove', 'preserve']:
                raise exceptions.CommandError(
                    _("The value of shutdown key of --block-device shall be "
                      "either 'remove' or 'preserve' but it was '%(action)s'")
                    % {'action': action})

            bdm_dict['delete_on_termination'] = (action == 'remove')
        elif bdm_dict.get('destination_type') == 'local':
            bdm_dict['delete_on_termination'] = True

        bdm.append(bdm_dict)
```
#### 3、发送boot 请求
```python
def do_boot(cs, args):
    """Boot a new server."""
    # 整理命令行参数，前面的逻辑都在这个 _boot 函数中
    boot_args, boot_kwargs = _boot(cs, args)

    #...省略多行..

    # 发送请求到 
    server = cs.servers.create(*boot_args, **boot_kwargs)
```

#### 4、nova-api 侧的块设备参数
从上面的过程我们能够看到，`cli` 参数在 `novaclient` 处做了一些预处理（整合）然后，在调用nova-api 创建虚拟机接口。到了 nova-api 侧参数如下例子：
```json
{
    "server": {
        "name": "\u751f\u4ea7\u8fd0\u8425\u76d1\u63a7\u7cfb\u7edf\u6570\u636e\u91c7\u96c6\u670d\u52a1\u5668",
        "availability_zone": "public",
        "block_device_mapping_v2": [
            {
                "source_type": "image",
                "boot_index": "0",
                "uuid": "dbbec6ed-017e-45b0-845d-45c73c718ac6",
                "volume_size": 100,
                "destination_type": "volume",
                "delete_on_termination": true,
                "volume_type": "SAS-public",
                "device_name": "vda"
            }
        ],
        "flavorRef": "98d0271a-6bc6-42dc-b8a2-62e4c688f333",
        "metadata": {
            "admin_pass": "***",
            "changePasswd": "True"
        },
        "networks": [
            {
                "ct_fixed_ips": [
                    {
                        "subnet_id": "a2b0a0ad-6278-400f-b53c-e4f1ccf8dad9"
                    }
                ],
                "uuid": "e2d8cd83-c2b0-4967-a163-8a4f338727a6"
            }
        ],
        "security_groups": [
            {
                "name": "dcf33623-e360-47eb-a856-b4db405bc47c"
            }
        ]
    }
}
```
### 块设备分类
- 由于源类型(image,snapshot,volume,blank)有这么几种可选
- 目的类型（volume,local）有这两种可选
- 上面参数可以组合出几种形态，依据不同的形态有不同的含义：


| dest  | source  | 说明  | shortcut  |
|---|---|---|---|
| volume  | volume  |  直接挂载到 compute 节点 | 当 boot_index = 0 时相当于 --boot-volume id  |
| volume  | snapshot | 调用 cinder 依据快照创建新卷，挂载到compute节点  | 当 boot_index = 0 时相当于 --snapshot id |
| volume  | image  | 调用cinder依据镜像创建新卷，挂载到compute节点  | 当 boot_index = 0 时相当于 --image id （Boot from image (creates a new volume)） |
| volume  | blank | 在 Hypervisor 上创建 ephemeral 分区，将 image 拷贝到里面并启动虚机 | 相当于普通的 Boot from image  |
| local  | image | 在 Hypervisor 上创建 ephemeral 分区，将 image 拷贝到里面并启动虚机 | 相当于普通的 Boot from image  |
|local|blank|format=swap 时，创建 swap 分区；默认创建 ephemeral  分区|当 boot_index=-1, shutdown=remove, format=swap 时相当于 --swap <swap size in MB>；当 boot_index=-1，shutdown=remove 时相当于 --ephemeral|

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
            # 然后这里将数据库类型的 bdms 封装成对于的blockdevice类
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