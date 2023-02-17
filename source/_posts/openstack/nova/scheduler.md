---
title:  nova scheduler
date: 2022-12-06 15:18:16
tags:
categories: OpenStack
---

## AggregateImagePropertiesIsolation
- host 属于某一个 aggregate
- aggregate 的 properties定义了镜像类型
- 匹配 aggregate 的 properties 和 instance 指定的镜像的 properties，可作为候选节点
- host 不属于任何 aggregate，可作为候选节点

```shell
$ openstack aggregate show myWinAgg
+-------------------+----------------------------+
| Field             | Value                      |
+-------------------+----------------------------+
| availability_zone | zone1                      |
| created_at        | 2017-01-01T15:36:44.000000 |
| deleted           | False                      |
| deleted_at        | None                       |
| hosts             | ['sf-devel']               |
| id                | 1                          |
| name              | myWinAgg                   |
| properties        | os_distro='windows'        |
| updated_at        | None                       |
+-------------------+----------------------------+
```

```shell
$ openstack image show Win-2012
+------------------+------------------------------------------------------+
| Field            | Value                                                |
+------------------+------------------------------------------------------+
| checksum         | ee1eca47dc88f4879d8a229cc70a07c6                     |
| container_format | bare                                                 |
| created_at       | 2016-12-13T09:30:30Z                                 |
| disk_format      | qcow2                                                |
| ...                                                                     |
| name             | Win-2012                                             |
| ...                                                                     |
| properties       | os_distro='windows'                                  |
| ...                                                                     |
```
- 假设创建虚拟选择了 Win-2012 镜像，镜像 Win-2012 有 os_distro='windows' 这个属性，节点 sf-devel 能够成为调度的候选节点。

## AggregateInstanceExtraSpecsFilter
- host 属于 aggregate 
- instance 的 flavor 中定义了extra specs
- 匹配 aggregate 的 properties 和 flavor 的 extra specs，可作为候选节点

## AllHostsFilter
- 不做任何操作，全部通过

## AvailabilityZoneFilter
- 保证 instance 的 az 和 host 的 az 一致

## ComputeFilter
- 所有的计算节点都是候选节点

## DifferentHostFilter
- 保证 instance 调度到与指定 instance 不同的 host 上
- 携带参数，格式如下：

```shell
# 和8c19174f-4220-44f0-824a-cd1eeef10287 、a0cf03a5-d921-4877-bb5c-86d26cf818e1 两个 instance 不在同一个 host
$ openstack server create \
  --image cedef40a-ed67-4d10-800e-17455edce175 --flavor 1 \
  --hint different_host=a0cf03a5-d921-4877-bb5c-86d26cf818e1 \
  --hint different_host=8c19174f-4220-44f0-824a-cd1eeef10287 \
  server-1
```
- api 请求格式如下：
```json
{
    "server": {
        "name": "server-1",
        "imageRef": "cedef40a-ed67-4d10-800e-17455edce175",
        "flavorRef": "1"
    },
    "os:scheduler_hints": {
        "different_host": [
            "a0cf03a5-d921-4877-bb5c-86d26cf818e1",
            "8c19174f-4220-44f0-824a-cd1eeef10287"
        ]
    }
}
```
## SameHostFilter
- 保证 instance 调度到与指定 instance 不同的 host 上
- 携带参数，格式如下：
```shell
$ openstack server create \
  --image cedef40a-ed67-4d10-800e-17455edce175 --flavor 1 \
  --hint same_host=a0cf03a5-d921-4877-bb5c-86d26cf818e1 \
  --hint same_host=8c19174f-4220-44f0-824a-cd1eeef10287 \
  server-1
```
- api 请求格式如下：
```json
{
    "server": {
        "name": "server-1",
        "imageRef": "cedef40a-ed67-4d10-800e-17455edce175",
        "flavorRef": "1"
    },
    "os:scheduler_hints": {
        "same_host": [
            "a0cf03a5-d921-4877-bb5c-86d26cf818e1",
            "8c19174f-4220-44f0-824a-cd1eeef10287"
        ]
    }
}
```

## ImagePropertiesFilter
- 镜像的 properties 是否和 host 的 properties 一致
- 主要查看如下属性:
    - hw_architecture : 例如 i686, x86_64, arm, ppc64
    - img_hv_type: 例如 qemu and hyperv.
    - img_hv_requested_version: 镜像需要的 hypervisor 版本，只对HyperV 这种类型的 hypervisor 有效
    - hw_vm_mode: describes the hypervisor application binary interface (ABI) required by the image. 

## IsolatedHostsFilter
- 设置一些隔离的 host
- 设置一些隔离的 image
- 选择这些 image 的 instance 只能调度到这些 host 上
- 在配置文件中配置

```ini
[filter_scheduler]
isolated_hosts = server1, server2
isolated_images = 342b492c-128f-4a42-8d3a-c5088cf27d13, ebd267a6-ca86-4d6c-9a0e-bd132d6b7d09
```
## ServerGroupAffinityFilter
- 让同属于一个亲和组的 instance 调度到相同的 host 上
```shell
$ openstack server group create --policy affinity group-1
$ openstack server create --image IMAGE_ID --flavor 1 \
  --hint group=SERVER_GROUP_UUID server-1
```

## ServerGroupAntiAffinityFilter
- 让属于同一个反亲和组的 instance 调度到不同节点上
```shell
$ openstack server group create --policy anti-affinity group-1
$ openstack server create --image IMAGE_ID --flavor 1 \
  --hint group=SERVER_GROUP_UUID server-1
```

## SimpleCIDRAffinityFilter
- 根据网段调度 instance
```shell
$ openstack server create \
  --image cedef40a-ed67-4d10-800e-17455edce175 --flavor 1 \
  --hint build_near_host_ip=192.168.1.1 --hint cidr=/24 \
  server-1
```
- api 参数格式如下：
```shell
{
    "server": {
        "name": "server-1",
        "imageRef": "cedef40a-ed67-4d10-800e-17455edce175",
        "flavorRef": "1"
    },
    "os:scheduler_hints": {
        "build_near_host_ip": "192.168.1.1",
        "cidr": "24"
    }
}
```
## NumInstancesFilter
- 如果 host 上已存在的 instance 数量超过限制，那么不作为候选节点
- 数值配置在 conf 文件中，filter_scheduler.max_instances_per_host

## NUMATopologyFilter
- 根据 NUMA 拓扑来调度 instance，这些指标存在于：
    - flavor 的 extra_specs
    - image 的 properties
