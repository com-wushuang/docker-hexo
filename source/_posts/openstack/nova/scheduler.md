---
title:  nova 调度解析
date: 2023-02-28 15:18:16
tags:
categories: OpenStack
---

## 基本概念
### 调度器
1、调度器：调度 Instance 在哪一个 Host 上运行的方式。目前 Nova 中实现的调度器方式由下列几种：
- `ChanceScheduler(随机调度器)`：从所有正常运行 `nova-compute` 服务的 `Host Node` 中随机选取来创建 `Instance`
- `FilterScheduler(过滤调度器)`：根据指定的过滤条件以及权重来挑选最佳创建 `Instance` 的 `Host Node`
- `Caching(缓存调度器)`：是 `FilterScheduler` 中的一种，在其基础上将 `Host` 资源信息缓存到本地的内存中，然后通过后台的定时任务从数据库中获取最新的 `Host` 资源信息。

2、为了便于扩展，Nova 将一个调度器必须要实现的接口提取出来成为 `nova.scheduler.driver.Scheduler`，只要继承了该类并实现其中的接口，我们就可以自定义调度器。

3、注意：不同的调度器并不能共存，需要在 `/etc/nova/nova.conf` 中的选项指定使用哪一个调度器。默认为 `FilterScheduler` 。

```
scheduler_driver = nova.scheduler.filter_scheduler.FilterScheduler
```

### 过滤调度器
1、`FilterScheduler` 首先使用指定的 `Filters(过滤器)` 过滤符合条件的 `Host`，然后对得到的 `Host` 列表计算 `Weighting` 权重并排序，获得最佳的 `Host` 。
![filterschedulerworkflow](https://raw.githubusercontent.com/com-wushuang/pics/main/filterschedulerworkflow.png)

2、过滤调度器主要由多个过滤器组成：过滤器都在 `nova.scheduler.filters` 路径下

### 代码架构图
![nova调度器代码架构](https://raw.githubusercontent.com/com-wushuang/pics/main/nova%E8%B0%83%E5%BA%A6%E5%99%A8%E4%BB%A3%E7%A0%81%E6%9E%B6%E6%9E%84.png)


## 创建虚拟机时序图
![instance_create_flow](https://raw.githubusercontent.com/com-wushuang/pics/main/instance_create_flow.png)

## 调度器工作时序图
调度器工作的时序图如下：
![how_scheduler_work](https://raw.githubusercontent.com/com-wushuang/pics/main/how_scheduler_work.png)

## 从日志层面解析调度流程
1、起点 `nova.scheduler.manager::SchedulerManager:select_destinations`
```
nova.scheduler.manager        Starting to schedule for instances: [u'3a09fd41-b36b-438d-9f59-35a98524165f'] select_destinations /usr/lib/python2.7/site-packages/nova/scheduler/manager.py:276
```
2、请求`Placement API`获取候选节点
```
nova.scheduler.client.report        Make a GET http request to /allocation_candidates?limit=1000&resources=INSTANCE%3A1%2CMEMORY_MB%3A1024%2CVCPU%3A1, request_id is req-61c3be56-ccba-4248-b04c-fb4448aace99. get /usr/lib/python2.7/site-packages/nova/scheduler/client/report.py:295
```
3、`nova.scheduler.filter_scheduler::FilterScheduler:_schedule` 调度器的主逻辑

4、`nova.scheduler.filter_scheduler::FilterScheduler:_get_all_host_states` 查询`compute_nodes` 并更新 `host_state`

```
nova.scheduler.host_manager        Getting compute nodes and services for cell 00000000-0000-0000-0000-000000000000(cell0) _get_computes_for_cells /usr/lib/python2.7/site-packages/nova/scheduler/host_manager.py:649
oslo_concurrency.lockutils        Lock "00000000-0000-0000-0000-000000000000" acquired by "nova.context.get_or_set_cached_cell_and_set_connections" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "00000000-0000-0000-0000-000000000000" released by "nova.context.get_or_set_cached_cell_and_set_connections" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
nova.scheduler.host_manager        Getting compute nodes and services for cell 432015b0-14e9-4e81-96eb-2ec36d79773b(cell1) _get_computes_for_cells /usr/lib/python2.7/site-packages/nova/scheduler/host_manager.py:649
oslo_concurrency.lockutils        Lock "432015b0-14e9-4e81-96eb-2ec36d79773b" acquired by "nova.context.get_or_set_cached_cell_and_set_connections" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "432015b0-14e9-4e81-96eb-2ec36d79773b" released by "nova.context.get_or_set_cached_cell_and_set_connections" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e18', u'sh11-compute-m3-10e5e12e18')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e18', u'sh11-compute-m3-10e5e12e18')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e17', u'sh11-compute-m3-10e5e12e17')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e17', u'sh11-compute-m3-10e5e12e17')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e25', u'sh11-compute-s3-10e5e12e25')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e25', u'sh11-compute-s3-10e5e12e25')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e19', u'sh11-compute-m3-10e5e12e19')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e19', u'sh11-compute-m3-10e5e12e19')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e22', u'sh11-compute-m3-10e5e12e22')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e22', u'sh11-compute-m3-10e5e12e22')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e26', u'sh11-compute-s3-10e5e12e26')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e26', u'sh11-compute-s3-10e5e12e26')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e21', u'sh11-compute-m3-10e5e12e21')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e21', u'sh11-compute-m3-10e5e12e21')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e20', u'sh11-compute-m3-10e5e12e20')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e20', u'sh11-compute-m3-10e5e12e20')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e29', u'sh11-compute-s3-10e5e12e29')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e29', u'sh11-compute-s3-10e5e12e29')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e23', u'sh11-compute-m3-10e5e12e23')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-m3-10e5e12e23', u'sh11-compute-m3-10e5e12e23')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e28', u'sh11-compute-s3-10e5e12e28')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e28', u'sh11-compute-s3-10e5e12e28')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-nfvm-compute-10e5e12e33', u'sh11-nfvm-compute-10e5e12e33')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-nfvm-compute-10e5e12e33', u'sh11-nfvm-compute-10e5e12e33')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-nfvm-compute-10e5e12e32', u'sh11-nfvm-compute-10e5e12e32')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-nfvm-compute-10e5e12e32', u'sh11-nfvm-compute-10e5e12e32')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e14', u'sh11-compute-fc1-10e5e12e14')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e14', u'sh11-compute-fc1-10e5e12e14')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e16', u'sh11-compute-fc1-10e5e12e16')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e16', u'sh11-compute-fc1-10e5e12e16')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e15', u'sh11-compute-fc1-10e5e12e15')" acquired by "nova.scheduler.host_manager._locked_update" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
oslo_concurrency.lockutils        Lock "(u'sh11-compute-fc1-10e5e12e15', u'sh11-compute-fc1-10e5e12e15')" released by "nova.scheduler.host_manager._locked_update" :: held 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
```
5、`nova.scheduler.filter_scheduler::FilterScheduler:_get_sorted_hosts` 执行每一个过滤器，过滤节点
```
nova.filters        Starting with 16 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:70
nova.filters        Filter RetryFilter returned 16 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.scheduler.filters.availability_zone_filter        Availability Zone 'SERIES-3-ZONE' requested. (sh11-nfvm-compute-10e5e12e33, sh11-nfvm-compute-10e5e12e33) ram: 232312MB disk: 242563072MB io_ops: 0 instances: 8 has AZs: set([u'cnp_sdn-NOVA-AZ2']) host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/availability_zone_filter.py:61
nova.scheduler.filters.availability_zone_filter        Availability Zone 'SERIES-3-ZONE' requested. (sh11-compute-fc1-10e5e12e15, sh11-compute-fc1-10e5e12e15) ram: 153738MB disk: 242563072MB io_ops: 0 instances: 0 has AZs: set([u'FEITENG-ZONE']) host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/availability_zone_filter.py:61
nova.scheduler.filters.availability_zone_filter        Availability Zone 'SERIES-3-ZONE' requested. (sh11-nfvm-compute-10e5e12e32, sh11-nfvm-compute-10e5e12e32) ram: 248696MB disk: 242563072MB io_ops: 0 instances: 6 has AZs: set([u'cnp_sdn-NOVA-AZ1']) host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/availability_zone_filter.py:61
nova.scheduler.filters.availability_zone_filter        Availability Zone 'SERIES-3-ZONE' requested. (sh11-compute-fc1-10e5e12e16, sh11-compute-fc1-10e5e12e16) ram: 153738MB disk: 242563072MB io_ops: 0 instances: 0 has AZs: set([u'FEITENG-ZONE']) host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/availability_zone_filter.py:61
nova.scheduler.filters.availability_zone_filter        Availability Zone 'SERIES-3-ZONE' requested. (sh11-compute-fc1-10e5e12e14, sh11-compute-fc1-10e5e12e14) ram: 137354MB disk: 242563072MB io_ops: 0 instances: 1 has AZs: set([u'FEITENG-ZONE']) host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/availability_zone_filter.py:61
nova.filters        Filter AvailabilityZoneFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter AggregateRamFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter AggregateDiskFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter ComputeFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter ComputeCapabilitiesFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter ImagePropertiesFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter ServerGroupAntiAffinityFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter ServerGroupAffinityFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter AggregateCoreFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter NumInstancesFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter SameHostFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter DifferentHostFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter LocalDiskFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter DedicatedCloudFilter returned 11 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e22, sh11-compute-m3-10e5e12e22) ram: 126071MB disk: 242563072MB io_ops: 0 instances: 5 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e18, sh11-compute-m3-10e5e12e18) ram: 126071MB disk: 242563072MB io_ops: 0 instances: 6 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e17, sh11-compute-m3-10e5e12e17) ram: 257143MB disk: 242563072MB io_ops: 0 instances: 4 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e20, sh11-compute-m3-10e5e12e20) ram: 388215MB disk: 242563072MB io_ops: 0 instances: 1 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e21, sh11-compute-m3-10e5e12e21) ram: 257143MB disk: 242563072MB io_ops: 0 instances: 2 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e23, sh11-compute-m3-10e5e12e23) ram: 289911MB disk: 242585600MB io_ops: 1 instances: 4 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.scheduler.filters.aggregate_instance_extra_specs        (sh11-compute-m3-10e5e12e19, sh11-compute-m3-10e5e12e19) ram: 27767MB disk: 242563072MB io_ops: 0 instances: 6 fails instance_type extra_specs requirements. 'set([u'cm3-optimized'])' do not match 's3-public' host_passes /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_instance_extra_specs.py:83
nova.filters        Filter AggregateInstanceExtraSpecsFilter returned 4 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter PciPassthroughFilter returned 4 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.filters        Filter VGPUFilter returned 4 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=86,cpuset=set([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81]),id=0,memory=257180,memory_usage=187392,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([24,80]),set([63,7]),set([0,56]),set([5,61]),set([18,74]),set([60,4]),set([17,73]),set([16,72]),set([13,69]),set([21,77]),set([78,22]),set([10,66]),set([25,81]),set([9,65]),set([1,57]),set([8,64]),set([67,11]),set([68,12]),set([75,19]),set([70,14]),set([59,3]),set([76,20]),set([71,15]),set([79,23]),set([2,58]),set([62,6])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Selected memory pagesize: 1048576 kB. Requested memory pagesize: 1048576 (small = -1, large = -2, any = -3) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1033
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=61,cpuset=set([28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109]),id=1,memory=258011,memory_usage=181248,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([33,89]),set([32,88]),set([43,99]),set([44,100]),set([37,93]),set([46,102]),set([36,92]),set([47,103]),set([39,95]),set([45,101]),set([35,91]),set([28,84]),set([31,87]),set([42,98]),set([30,86]),set([41,97]),set([40,96]),set([29,85]),set([51,107]),set([50,106]),set([52,108]),set([49,105]),set([48,104]),set([38,94]),set([53,109]),set([34,90])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Selected memory pagesize: 1048576 kB. Requested memory pagesize: 1048576 (small = -1, large = -2, any = -3) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1033
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=84,cpuset=set([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81]),id=0,memory=257180,memory_usage=204800,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([24,80]),set([7,63]),set([0,56]),set([5,61]),set([18,74]),set([4,60]),set([17,73]),set([16,72]),set([13,69]),set([21,77]),set([22,78]),set([10,66]),set([25,81]),set([9,65]),set([1,57]),set([8,64]),set([11,67]),set([12,68]),set([19,75]),set([14,70]),set([3,59]),set([20,76]),set([15,71]),set([23,79]),set([2,58]),set([6,62])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Selected memory pagesize: 1048576 kB. Requested memory pagesize: 1048576 (small = -1, large = -2, any = -3) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1033
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=73,cpuset=set([28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109]),id=1,memory=258011,memory_usage=205824,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([33,89]),set([32,88]),set([43,99]),set([44,100]),set([37,93]),set([46,102]),set([36,92]),set([47,103]),set([39,95]),set([45,101]),set([35,91]),set([28,84]),set([31,87]),set([42,98]),set([30,86]),set([41,97]),set([40,96]),set([29,85]),set([51,107]),set([50,106]),set([52,108]),set([49,105]),set([48,104]),set([38,94]),set([53,109]),set([34,90])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Host does not support requested memory pagesize. Requested: 1048576 kB _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1027
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=70,cpuset=set([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81]),id=0,memory=257180,memory_usage=190464,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([24,80]),set([7,63]),set([0,56]),set([5,61]),set([18,74]),set([4,60]),set([17,73]),set([16,72]),set([13,69]),set([21,77]),set([22,78]),set([10,66]),set([25,81]),set([9,65]),set([1,57]),set([8,64]),set([11,67]),set([12,68]),set([19,75]),set([14,70]),set([3,59]),set([20,76]),set([15,71]),set([23,79]),set([2,58]),set([6,62])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Selected memory pagesize: 1048576 kB. Requested memory pagesize: 1048576 (small = -1, large = -2, any = -3) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1033
nova.filters        Filter NUMATopologyFilter returned 4 host(s) get_filtered_objects /usr/lib/python2.7/site-packages/nova/filters.py:104
nova.scheduler.filter_scheduler        Filtered [(sh11-compute-s3-10e5e12e25, sh11-compute-s3-10e5e12e25) ram: 27767MB disk: 242563072MB io_ops: 0 instances: 21, (sh11-compute-s3-10e5e12e26, sh11-compute-s3-10e5e12e26) ram: 36983MB disk: 242563072MB io_ops: 0 instances: 14, (sh11-compute-s3-10e5e12e28, sh11-compute-s3-10e5e12e28) ram: 28791MB disk: 242563072MB io_ops: 0 instances: 16, (sh11-compute-s3-10e5e12e29, sh11-compute-s3-10e5e12e29) ram: 24695MB disk: 242563072MB io_ops: 0 instances: 20] _get_sorted_hosts /usr/lib/python2.7/site-packages/nova/scheduler/filter_scheduler.py:432
nova.scheduler.filter_scheduler        Weighed [(sh11-compute-s3-10e5e12e26, sh11-compute-s3-10e5e12e26) ram: 36983MB disk: 242563072MB io_ops: 0 instances: 14, (sh11-compute-s3-10e5e12e28, sh11-compute-s3-10e5e12e28) ram: 28791MB disk: 242563072MB io_ops: 0 instances: 16, (sh11-compute-s3-10e5e12e25, sh11-compute-s3-10e5e12e25) ram: 27767MB disk: 242563072MB io_ops: 0 instances: 21, (sh11-compute-s3-10e5e12e29, sh11-compute-s3-10e5e12e29) ram: 24695MB disk: 242563072MB io_ops: 0 instances: 20] _get_sorted_hosts /usr/lib/python2.7/site-packages/nova/scheduler/filter_scheduler.py:452
```
6、`nova.scheduler.utils:claim_resources` 调用 `Placement API` 去 `claim resource`.
```
nova.scheduler.utils        Attempting to claim resources in the placement API for instance 3a09fd41-b36b-438d-9f59-35a98524165f claim_resources /usr/lib/python2.7/site-packages/nova/scheduler/utils.py:814
nova.scheduler.client.report        Make a GET http request to /allocations/3a09fd41-b36b-438d-9f59-35a98524165f, request_id is req-61c3be56-ccba-4248-b04c-fb4448aace99. get /usr/lib/python2.7/site-packages/nova/scheduler/client/report.py:295
nova.scheduler.filter_scheduler        Selected host: (sh11-compute-s3-10e5e12e26, sh11-compute-s3-10e5e12e26) ram: 36983MB disk: 242563072MB io_ops: 0 instances: 14 _consume_selected_host /usr/lib/python2.7/site-packages/nova/scheduler/filter_scheduler.py:337
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e26', u'sh11-compute-s3-10e5e12e26')" acquired by "nova.scheduler.host_manager._locked" :: waited 0.000s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:273
nova.virt.hardware        Attempting to fit instance cell InstanceNUMACell(cpu_pinning_raw=None,cpu_policy=None,cpu_thread_policy=None,cpu_topology=<?>,cpuset=set([0]),cpuset_reserved=None,id=0,memory=1024,pagesize=1048576) on host_cell NUMACell(cpu_usage=61,cpuset=set([28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109]),id=1,memory=258011,memory_usage=181248,mempages=[NUMAPagesTopology,NUMAPagesTopology],pinned_cpus=set([]),siblings=[set([33,89]),set([32,88]),set([43,99]),set([44,100]),set([37,93]),set([46,102]),set([36,92]),set([47,103]),set([39,95]),set([45,101]),set([35,91]),set([28,84]),set([31,87]),set([42,98]),set([30,86]),set([41,97]),set([40,96]),set([29,85]),set([51,107]),set([50,106]),set([52,108]),set([49,105]),set([48,104]),set([38,94]),set([53,109]),set([34,90])]) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:977
nova.virt.hardware        No pinning requested, considering limitations on usable cpu and memory _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1002
nova.virt.hardware        Selected memory pagesize: 1048576 kB. Requested memory pagesize: 1048576 (small = -1, large = -2, any = -3) _numa_fit_instance_cell /usr/lib/python2.7/site-packages/nova/virt/hardware.py:1033
oslo_concurrency.lockutils        Lock "(u'sh11-compute-s3-10e5e12e26', u'sh11-compute-s3-10e5e12e26')" released by "nova.scheduler.host_manager._locked" :: held 0.005s inner /usr/lib/python2.7/site-packages/oslo_concurrency/lockutils.py:285
oslo_messaging.rpc.server        Replied incoming message with id 4b6022ed7d7744089c896ef2d07cb39a and method: select_destinations. Time elapsed: 1.278
```
## 从源码层面解析调度流程
### 阶段一、请求流转
- 调用链：`nova-conductor ==> RPC scheduler_client.select_destinations() ==> nova-sechduler`
- 发起方 `nova-conductor`的函数调用链如下：
```python
#nova.conductor.manager.ComputeTaskManager:build_instances()

    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping=None, legacy_bdm=True,
            request_spec=None, host_lists=None):

        # get appropriate hosts for the request.
        host_lists = self._schedule_instances(context, spec_obj, instance_uuids, return_alternates=True)


    def _schedule_instances(self, context, request_spec,
                            instance_uuids=None, return_alternates=False):
        scheduler_utils.setup_instance_group(context, request_spec)
        host_lists = self.scheduler_client.select_destinations(context,
                request_spec, instance_uuids, return_objects=True,
                return_alternates=return_alternates)
        return host_lists
```
- RPC scheduler_client.select_destinations() 函数调用链如下：
```python
# nova.scheduler.client.query.SchedulerQueryClient:select_destinations()

from nova.scheduler import rpcapi as scheduler_rpcapi

class SchedulerQueryClient(object):
    """Client class for querying to the scheduler."""

    def __init__(self):
        self.scheduler_rpcapi = scheduler_rpcapi.SchedulerAPI()

    def select_destinations(self, context, spec_obj, instance_uuids,
            return_objects=False, return_alternates=False):    
        LOG.debug("SchedulerQueryClient starts to make a RPC call.")
        return self.scheduler_rpcapi.select_destinations(context, spec_obj,
                instance_uuids, return_objects, return_alternates)


# nova.scheduler.rpcapi.SchedulerAPI:select_destinations()

    def select_destinations(self, ctxt, request_spec, filter_properties):
        cctxt = self.client.prepare(version='4.5')
        return cctxt.call(ctxt, 'select_destinations', **msg_args)
```
### 阶段二：RPC 请求到达 nova-scheduler 服务 SchedulerManager
```python
# nova.scheduler.manager.SchedulerManager:select_destinations()
class SchedulerManager(manager.Manager):
    """Chooses a host to run instances on."""

    target = messaging.Target(version='4.5')

    def __init__(self, scheduler_driver=None, *args, **kwargs):
        if not scheduler_driver:
            scheduler_driver = CONF.scheduler_driver
        # 可以看出这里的 driver 是通过配置文件中的选项值指定的类来返回的对象 EG.nova.scheduler.filter_scheduler.FilterScheduler
        self.driver = driver.DriverManager(
                "nova.scheduler.driver",
                scheduler_driver,
                invoke_on_load=True).driver
        super(SchedulerManager, self).__init__(service_name='scheduler',
                                               *args, **kwargs)


    def select_destinations(self, ctxt, request_spec=None,
            filter_properties=None, spec_obj=_sentinel, instance_uuids=None,
            return_objects=False, return_alternates=False):
        # get allocation candidates from nova placement api 获取候选节点
        res = self.placement_client.get_allocation_candidates(ctxt,resources)
        
        (alloc_reqs, provider_summaries,allocation_request_version) = res

        selections = self.driver.select_destinations(ctxt, spec_obj,
                instance_uuids, alloc_reqs_by_rp_uuid, provider_summaries,
                allocation_request_version, return_alternates)
```
- 关键函数：`self.placement_client.get_allocation_candidates(ctxt,resources)` 调用 `nova-placement api` 获得候选节点
### 阶段三：从 SchedulerManager 到调度器 FilterScheduler
**宏观流程** 
```python
# nova.scheduler.filter_scheduler.FilterScheduler:select_destinations()

class FilterScheduler(driver.Scheduler):
    """Scheduler that can be used for filtering and weighing."""
    def __init__(self, *args, **kwargs):
        super(FilterScheduler, self).__init__(*args, **kwargs)
        self.notifier = rpc.get_notifier('scheduler')
        scheduler_client = client.SchedulerClient()
        self.placement_client = scheduler_client.reportclient

    def select_destinations(self, context, spec_obj, instance_uuids,
            alloc_reqs_by_rp_uuid, provider_summaries,
            allocation_request_version=None, return_alternates=False):

        self.notifier.info(
            context, 'scheduler.select_destinations.start',
            dict(request_spec=spec_obj.to_legacy_request_spec_dict()))

        host_selections = self._schedule(context, spec_obj, instance_uuids,
                alloc_reqs_by_rp_uuid, provider_summaries,
                allocation_request_version, return_alternates)
        self.notifier.info(
            context, 'scheduler.select_destinations.end',
            dict(request_spec=spec_obj.to_legacy_request_spec_dict()))
        return host_selections


    def _schedule(self, context, spec_obj, instance_uuids,
            alloc_reqs_by_rp_uuid, provider_summaries,
            allocation_request_version=None, return_alternates=False):
        
        # context 升级权限
        elevated = context.elevated()

        # 获取候选节点的状态，并不是获取集群所有节点的状态
        hosts = self._get_all_host_states(elevated, spec_obj,
            provider_summaries)

        # 需要创建的 Instances 的数量
        num_instances = (len(instance_uuids) if instance_uuids
                         else spec_obj.num_instances)

        # 记录已经在 placement API 成功 claimed 的 instances.
        # 如果调度的过程失败了，便于回滚 placement API 数据
        claimed_instance_uuids = []

        # 记录已经在 placement API 成功 claimed 的 hosts
        claimed_hosts = []

        for num in range(num_instances):
            hosts = self._get_sorted_hosts(spec_obj, hosts, num)
            if not hosts:
                # 批量创建有一个调度失败，那么就直接跳出循环
                # 也就是说openstack的保证了批量创建的所有虚拟机都成功调度
                break


            instance_uuid = instance_uuids[num]

            # 调用 placement API 去 claim resource
            claimed_host = None
            for host in hosts:
                cn_uuid = host.uuid
                if cn_uuid not in alloc_reqs_by_rp_uuid:
                    msg = ("A host state with uuid = '%s' that did not have a "
                          "matching allocation_request was encountered while "
                          "scheduling. This host was skipped.")
                    LOG.debug(msg, cn_uuid)
                    continue

                alloc_reqs = alloc_reqs_by_rp_uuid[cn_uuid]
                alloc_req = alloc_reqs[0]
                if utils.claim_resources(elevated, self.placement_client,
                        spec_obj, instance_uuid, alloc_req,
                        allocation_request_version=allocation_request_version):
                    claimed_host = host
                    break

            if claimed_host is None:
                LOG.debug("Unable to successfully claim against any host.")
                break

            claimed_instance_uuids.append(instance_uuid)
            claimed_hosts.append(claimed_host)

            # 更新被选中的 host 的 host_state,下一个虚拟机在被调度的时候就是新的host_state
            self._consume_selected_host(claimed_host, spec_obj)

            # For the live-resize instance local, consume selected host,
            # allocate numa_topology failed raise no valid host.
            if utils.request_is_live_resize(spec_obj) and \
                    claimed_host.host == spec_obj.original_instance.host \
                    and (not spec_obj.numa_topology):
                reason = "The numa topology allocated insuffecient."
                raise exception.NoValidHost(reason=reason)
        # 检查调度选择出的节点数量和虚拟机的数量一直，如果不一致，则清理资源
        self._ensure_sufficient_hosts(context, claimed_hosts, num_instances,
                claimed_instance_uuids)

        # We have selected and claimed hosts for each instance. Now we need to
        # find alternates for each host.
        selections_to_return = self._get_alternate_hosts(
            claimed_hosts, spec_obj, hosts, num, num_alts,
            alloc_reqs_by_rp_uuid, allocation_request_version)
        return selections_to_return
```
**微观两个重要的函数**
1. `_get_all_host_states`:获取所有的 Host 状态，并且将初步满足条件的 Hosts 过滤出来。
2. `_get_sorted_hosts`:使用 Filters 过滤器将第一个函数返回的 hosts 进行再一次过滤，然后通过 Weighed 选取最优 Host。

#### _get_all_host_states 函数

- `host_manager` 是 `nova.scheduler.driver.Scheduler` 的成员变量
```python
# nova.scheduler.driver.Scheduler:__init__()

# nova.scheduler.filter_scheduler.FilterScheduler 继承了 nova.scheduler.driver.Scheduler
 class Scheduler(object):
     """The base class that all Scheduler classes should inherit from."""

     def __init__(self):
         # 从这里知道 host_manager 会根据配置文件动态导入
         self.host_manager = importutils.import_object(
                 CONF.scheduler_host_manager)
         self.servicegroup_api = servicegroup.API()
```
- `_get_all_host_states` 调用成员变量`host_manager`的函数如下：
```python
    def _get_all_host_states(self, context, spec_obj, provider_summaries):
        compute_uuids = None
        if provider_summaries is not None:
            compute_uuids = list(provider_summaries.keys())
        return self.host_manager.get_host_states_by_uuids(context,compute_uuids,spec_obj)
```
-  `host_manager`的`get_host_states_by_uuids`函数如下：
```python
    def get_host_states_by_uuids(self, context, compute_uuids, spec_obj):

        self._load_cells(context)
        if (spec_obj and 'requested_destination' in spec_obj and
                spec_obj.requested_destination and
                'cell' in spec_obj.requested_destination):
            only_cell = spec_obj.requested_destination.cell
        else:
            only_cell = None

        if only_cell:
            cells = [only_cell]
        else:
            cells = self.cells

        # 查询 compute_nodes 信息，然后作为参数继续调用
        compute_nodes, services = self._get_computes_for_cells(
            context, cells, compute_uuids=compute_uuids)
        return self._get_host_states(context, compute_nodes, services)
```
- `_get_host_states` 函数如下：
```python
    def _get_host_states(self, context, compute_nodes, services):
        """Returns a generator over HostStates given a list of computes.

        Also updates the HostStates internal mapping for the HostManager.
        """
        # Get resource usage across the available compute nodes:
        host_state_map = {}
        seen_nodes = set()
        for cell_uuid, computes in compute_nodes.items():
            for compute in computes:
                service = services.get(compute.host)

                if not service:
                    LOG.warning(_LW(
                        "No compute service record found for host %(host)s"),
                        {'host': compute.host})
                    continue
                host = compute.host
                node = compute.hypervisor_hostname
                state_key = (host, node)
                host_state = host_state_map.get(state_key)
                if not host_state:
                    host_state = self.host_state_cls(host, node,
                                                     cell_uuid,
                                                     compute=compute)
                    host_state_map[state_key] = host_state
                # We force to update the aggregates info each time a
                # new request comes in, because some changes on the
                # aggregates could have been happening after setting
                # this field for the first time
                host_state.update(compute,
                                  dict(service),
                                  self._get_aggregates_info(host),
                                  self._get_instance_info(context, compute))

                seen_nodes.add(state_key)

        return (host_state_map[host] for host in seen_nodes)
```
- 总结：`_get_all_host_states` 函数主要的作用就是查询 compute_nodes 信息（从数据库）。然后存储在 `HostState` 类中

#### _get_sorted_hosts 函数
```python
    def _get_sorted_hosts(self, spec_obj, host_states, index):
        filtered_hosts = self.host_manager.get_filtered_hosts(host_states,
            spec_obj, index)

        weighed_hosts = self.host_manager.get_weighed_hosts(filtered_hosts,
            spec_obj)
```

## 调度涉及的其他服务
### nova placement api
#### 1、Get allocation candidates
- **接口描述**:选取资源分配候选者
- **接口地址**:GET /placement/allocation_candidates
- **请求参数**：resources=DISK_GB:1,MEMORY_MB:512,VCPU:1
- **请求示例**:
```shell
curl -H "x-auth-token:$(openstack token issue | awk '/ id /{print $(NF-1)}')" -H 'OpenStack-API-Version: placement 1.17' 'http://nova-placement-api.cty.os:10013/allocation_candidates?limit=1000&resources=INSTANCE:10,MEMORY_MB:4096,VCPU:4' | python -m json.tool
```
- **响应示例**:
```json
{
    "provider_summaries": {
        "4cae2ef8-30eb-4571-80c3-3289e86bd65c": {
            "resources": {
                "VCPU": {
                    "used": 2,
                    "capacity": 64
                },
                "MEMORY_MB": {
                    "used": 1024,
                    "capacity": 11374
                },
                "DISK_GB": {
                    "used": 2,
                    "capacity": 49
                }
            }
        }
    },
    "allocation_requests": [
        {
            "allocations": [
                {
                    "resource_provider": {
                        "uuid": "4cae2ef8-30eb-4571-80c3-3289e86bd65c"
                    },
                    "resources": {
                        "VCPU": 1,
                        "MEMORY_MB": 512,
                        "DISK_GB": 1
                    }
                }
            ]
        }
    ]
}
```
#### 2、Claim Resources
- **接口描述**:分配资源
- **接口地址**:/allocations/{consumer_uuid}
- **请求参数**: POST
```json
{
  "allocations": {
    "4e061c03-611e-4caa-bf26-999dcff4284e": {
      "resources": {
        "DISK_GB": 20
      }
    },
    "89873422-1373-46e5-b467-f0c5e6acf08f": {
      "resources": {
        "MEMORY_MB": 1024,
        "VCPU": 1
      }
    }
  },
  "consumer_generation": 1,
  "user_id": "66cb2f29-c86d-47c3-8af5-69ae7b778c70",
  "project_id": "42a32c07-3eeb-4401-9373-68a8cdca6784",
  "consumer_type": "INSTANCE"
}
```
- **响应示例**:
```json
{
  "allocations": {
    "4e061c03-611e-4caa-bf26-999dcff4284e": {
      "resources": {
        "DISK_GB": 20
      }
    },
    "89873422-1373-46e5-b467-f0c5e6acf08f": {
      "resources": {
        "MEMORY_MB": 1024,
        "VCPU": 1
      }
    }
  },
  "consumer_generation": 1,
  "user_id": "66cb2f29-c86d-47c3-8af5-69ae7b778c70",
  "project_id": "42a32c07-3eeb-4401-9373-68a8cdca6784",
  "consumer_type": "INSTANCE"
}
```
## 调度涉及的数据库模型
