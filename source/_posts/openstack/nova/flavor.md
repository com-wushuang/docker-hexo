---
title:  nova flavor
date: 2022-12-07 15:18:17
tags:
categories: OpenStack
---

## 概述
flavor 定义了一个虚拟机的 cpu、memory、disk 等的大小。简单来说，flavor 表示了一个虚拟机的硬件规格。一个flavor包含了如下的属性：

- Flavor ID:唯一ID.
- Name:名称.
- VCPUs:vcpu的数量.
- Memory MB:RAM的大小.
- Root Disk GB:根分区的大小.
- Ephemeral Disk GB:临时盘，非持久性存储空间，会随着虚拟机的生命周期被创建和回收.
- Swap:交换分区的大小.
- Is Public:是否公开能被他人使用.
- Extra Specs:键值对，和调度相关.
- Description:描述.

## 管理flavor

- Create a flavor
```shell
penstack flavor create --public m1.extra_tiny --id auto --ram 256 --disk 0 --vcpus 1
```
- Modify a flavor
```shell
openstack flavor set --description <DESCRIPTION> <FLAVOR>
```
- Delete a flavor
```shell
openstack flavor delete FLAVOR
```

## 和调度相关的 Extra Specs
### AggregateInstanceExtraSpecsFilter
- 匹配 flavor 的 extra specs 和 aggregate 的 metadata
- 并不是所有的都匹配，匹配的格式如下两类：
    - `"aggregate_instance_extra_specs:key":"value"`(scope format)
    - `"key":"value"`(not scope format):所有这种格式的都会去匹配
```python
    def host_passes(self, host_state, spec_obj):
        """Return a list of hosts that can create flavor.
        Check that the extra specs associated with the instance type match
        the metadata provided by aggregates.  If not present return False.
        """
        flavor = spec_obj.flavor
        # If 'extra_specs' is not present or extra_specs are empty then we
        # need not proceed further
        if 'extra_specs' not in flavor or not flavor.extra_specs:
            return True

        metadata = utils.aggregate_metadata_get_by_host(host_state) # 获得host的metadata

        for key, req in flavor.extra_specs.items():
            # Either not scope format, or aggregate_instance_extra_specs scope # 过滤上文中提到的那两种类型的specs
            scope = key.split(':', 1)
            if len(scope) > 1:
                if scope[0] != _SCOPE: # _SCOPE = 'aggregate_instance_extra_specs'
                    continue
                else:
                    del scope[0]
            key = scope[0]
            aggregate_vals = metadata.get(key, None)
            if not aggregate_vals:
                LOG.debug(
                    "%(host_state)s fails flavor extra_specs requirements. "
                    "Extra_spec %(key)s is not in aggregate.",
                    {'host_state': host_state, 'key': key})
                return False
            for aggregate_val in aggregate_vals:
                if extra_specs_ops.match(aggregate_val, req):
                    break
            else:
                LOG.debug(
                    "%(host_state)s fails flavor extra_specs requirements. "
                    "'%(aggregate_vals)s' do not match '%(req)s'",
                    {
                        'host_state': host_state, 'req': req,
                        'aggregate_vals': aggregate_vals,
                    })
                return False
        return True
```

### ComputeCapabilitiesFilter
- 匹配 flavor 的 extra specs 和 host 的 cap
- 并不是所有的都匹配，匹配的格式如下两类：
    - `"capabilities:key":"value"`(scope format)
    - `"key":"value"`(not scope format):并部署所有这种格式的都会去匹配，有些会忽略，可以看代码注释，解释的非常清楚

```python
    def _satisfies_extra_specs(self, host_state, flavor):
        """Check that the host_state provided by the compute service
        satisfies the extra specs associated with the instance type.
        """
        if 'extra_specs' not in flavor:
            return True

        for key, req in flavor.extra_specs.items():
            # Either not scope format, or in capabilities scope
            scope = key.split(':')
            # If key does not have a namespace, the scope's size is 1, check
            # whether host_state contains the key as an attribute. If not,
            # ignore it. If it contains, deal with it in the same way as
            # 'capabilities:key'. This is for backward-compatible.
            # If the key has a namespace, the scope's size will be bigger than
            # 1, check that whether the namespace is 'capabilities'. If not,
            # ignore it.
            if len(scope) == 1:
                stats = getattr(host_state, 'stats', {})
                has_attr = hasattr(host_state, key) or key in stats
                if not has_attr:
                    continue
            else:
                if scope[0] != "capabilities":
                    continue
                else:
                    del scope[0]

            cap = self._get_capabilities(host_state, scope)
            if cap is None:
                return False

            if not extra_specs_ops.match(str(cap), req):
                LOG.debug("%(host_state)s fails extra_spec requirements. "
                          "'%(req)s' does not match '%(cap)s'",
                          {'host_state': host_state, 'req': req,
                           'cap': cap})
                return False
        return True
```