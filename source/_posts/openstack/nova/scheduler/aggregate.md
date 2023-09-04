---
title:  nova aggreagte
date: 2022-12-07 15:18:17
tags:
categories: OpenStack
---

## 概述
- host aggregates 用来对主机进行分组
- 每一个 aggregate 可以包含多个键值对
- 每一个 host 可以属于多个 aggregate
- 常常被用在 scheduler 中
- host aggregate 通常是对用户透明的
- 用户使用 flavor 来使用 aggregate：通过AggregateInstanceExtraSpecsFilter
- Availability zone 对用户来说是透明的，并且 host 只能属于一个 Availability zone
- aggregate 简单理解就是标签组
- host 加入到 aggregate 就相当于拥有了 aggregate 的所有标签

## aggregate 在调度器中的运用
- aggregate 最常见的应用场景，当你想要将虚拟机调度到具有特殊能力的节点上时。比如，用户想要虚拟机具有 SSD特性、GPU加速特性，那么他就需要让虚拟机调度到具有这些特性的计算节点上。当然，用户是通过选择 flavor 的方式达到（用户对scheduler、aggregate都是无感知的，用户只对flavor有感知）
- scheduler 支持aggregate，通过如下的范式配置:
```ini
[filter_scheduler]
enabled_filters=...,AggregateInstanceExtraSpecsFilter
```

## 例子:指定计算节点的SSD属性
- 创建一个 aggregate:
```shell
openstack aggregate create --zone nova fast-io
+-------------------+----------------------------+
| Field             | Value                      |
+-------------------+----------------------------+
| availability_zone | nova                       |
| created_at        | 2016-12-22T07:31:13.013466 |
| deleted           | False                      |
| deleted_at        | None                       |
| id                | 1                          |
| name              | fast-io                    |
| updated_at        | None                       |
+-------------------+----------------------------+
```
- 给 aggregate 设置键值对:
```shell
 openstack aggregate set --property ssd=true 1
+-------------------+----------------------------+
| Field             | Value                      |
+-------------------+----------------------------+
| availability_zone | nova                       |
| created_at        | 2016-12-22T07:31:13.000000 |
| deleted           | False                      |
| deleted_at        | None                       |
| hosts             | []                         |
| id                | 1                          |
| name              | fast-io                    |
| properties        | ssd='true'                 |
| updated_at        | None                       |
+-------------------+----------------------------+
```
- 加入计算节点 node1、node2
```
openstack aggregate add host 1 node1
openstack aggregate add host 1 node2
```
- 创建 flavor 
```
openstack flavor create --id 6 --ram 8192 --disk 80 --vcpus 4 ssd.large
+----------------------------+-----------+
| Field                      | Value     |
+----------------------------+-----------+
| OS-FLV-DISABLED:disabled   | False     |
| OS-FLV-EXT-DATA:ephemeral  | 0         |
| disk                       | 80        |
| id                         | 6         |
| name                       | ssd.large |
| os-flavor-access:is_public | True      |
| ram                        | 8192      |
| rxtx_factor                | 1.0       |
| swap                       |           |
| vcpus                      | 4         |
+----------------------------+-----------+
```
- 给 flavor 打标签
```shell
openstack flavor set \
    --property aggregate_instance_extra_specs:ssd=true ssd.large
```
- 查看 flavor
```
openstack flavor show ssd.large
+----------------------------+-------------------------------------------+
| Field                      | Value                                     |
+----------------------------+-------------------------------------------+
| OS-FLV-DISABLED:disabled   | False                                     |
| OS-FLV-EXT-DATA:ephemeral  | 0                                         |
| disk                       | 80                                        |
| id                         | 6                                         |
| name                       | ssd.large                                 |
| os-flavor-access:is_public | True                                      |
| properties                 | aggregate_instance_extra_specs:ssd='true' |
| ram                        | 8192                                      |
| rxtx_factor                | 1.0                                       |
| swap                       |                                           |
| vcpus                      | 4                                         |
+----------------------------+-------------------------------------------+
```
- 现在，当用户创建 flavor 为 ssd.large 的虚拟机，只会被调到带有 ssd=true 标签的 host 上。
