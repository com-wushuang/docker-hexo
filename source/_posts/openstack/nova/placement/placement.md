---
title:  nova placement
date: 2022-12-08 15:18:17
tags:
categories: OpenStack
---

## Placement API 概述
- 由于历史遗留原因，Nova认为资源全部是由计算节点提供，所以在报告某些资源使用时，Nova仅仅通过查询数据库中不同计算节点的数据，简单的做累加计算得到使用量和可用资源情况，这一定不是严谨科学的做法。
- 于是，在N版中，Nova引入了Placement API，这是一个单独的 RESTful API 和数据模型，用于管理和查询资源提供者的资源存量、使用情况、分配记录等等，以提供更好、更准确的资源跟踪、调度和分配的功能。例如，一个资源提供者可以是计算节点、共享存储池、IP池。
- Placement Service 让其他的项目能够跟踪他们的资源的使用情况。这些项目能够通过Placement API 注册、删除他们自己的资源。

## Nova服务是如何使用Placement的
在 nova 中有两处地方使用到了 placement（placement 服务被设计出来不只是为了给 nova 使用）。
### nova-compute
**1、Create resource provider**
- 注册 nova 计算节点为资源提供者，每个计算节点都需要注册,注册后数据库如下：
```sql
select id, name, uuid from resource_providers;

+----+-----------------------+--------------------------------------+
| id | name                  | uuid                                 |
+----+-----------------------+--------------------------------------+
|  1 | ytj-ceshi-10e101e8e11 | 22aa877f-ce8f-48a4-a091-61fed74e5ac3 |
|  4 | ytj-ceshi-10e101e8e12 | 014e078b-37ff-4f6f-a3a5-0e7583ba235e |
|  7 | ytj-ceshi-10e101e8e13 | c5897c40-968d-40dc-b16f-99b44ec72d4a |
+----+-----------------------+--------------------------------------+
```
- 通过如下的API注册成为 resource provider：
```json
POST /resource_providers

request body
{
    "name": "NFS Share",
    "uuid": "7d2590ae-fb85-4080-9306-058b4c915e3f",
    "parent_provider_uuid": "542df8ed-9be2-49b9-b4db-6d3183ff8ec8"
}

response body
{
    "generation": 0,
    "links": [
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f",
            "rel": "self"
        },
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f/aggregates",
            "rel": "aggregates"
        },
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f/inventories",
            "rel": "inventories"
        },
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f/usages",
            "rel": "usages"
        },
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f/traits",
            "rel": "traits"
        },
        {
            "href": "/placement/resource_providers/7d2590ae-fb85-4080-9306-058b4c915e3f/allocations",
            "rel": "allocations"
        }
    ],
    "name": "NFS Share",
    "uuid": "7d2590ae-fb85-4080-9306-058b4c915e3f",
    "parent_provider_uuid": "542df8ed-9be2-49b9-b4db-6d3183ff8ec8",
    "root_provider_uuid": "542df8ed-9be2-49b9-b4db-6d3183ff8ec8"
}
```

**1、Setting the inventory**
- 注册完 resource provider 之后，还需要设置 inventory，设置的API如下：
```json
PUT /resource_providers/{uuid}/inventories

request body
{
    "inventories": {
        "MEMORY_MB": {
            "allocation_ratio": 2.0,
            "max_unit": 16,
            "step_size": 4,
            "total": 128
        },
        "VCPU": {
            "allocation_ratio": 10.0,
            "reserved": 2,
            "total": 64
        }
    },
    "resource_provider_generation": 1
}

response body
{
    "inventories": {
        "MEMORY_MB": {
            "allocation_ratio": 2.0,
            "max_unit": 16,
            "min_unit": 1,
            "reserved": 0,
            "step_size": 4,
            "total": 128
        },
        "VCPU": {
            "allocation_ratio": 10.0,
            "max_unit": 2147483647,
            "min_unit": 1,
            "reserved": 2,
            "step_size": 1,
            "total": 64
        }
    },
    "resource_provider_generation": 2
}
```
- 设置完资源的 inventory 后数据库数据如下：
```sql
+----+----------------------+-------------------+--------+----------+----------+----------+-----------+------------------+
| id | resource_provider_id | resource_class_id | total  | reserved | min_unit | max_unit | step_size | allocation_ratio |
+----+----------------------+-------------------+--------+----------+----------+----------+-----------+------------------+
|  1 |                    1 |                 0 |     76 |        0 |        1 |      228 |         1 |                3 |
|  4 |                    1 |                 1 | 772669 |    88064 |        1 |   772669 |         1 |                1 |
|  7 |                    1 |                 2 | 214092 |      100 |        1 |   214092 |         1 |                1 |
| 10 |                    1 |                12 |    150 |        0 |        1 |      150 |         1 |                1 |
| 13 |                    1 |             10000 |   1024 |        0 |        1 |     1024 |         1 |                1 |
| 16 |                    4 |                 0 |     76 |        0 |        1 |      228 |         1 |                3 |
| 19 |                    4 |                 1 | 772667 |    88064 |        1 |   772667 |         1 |                1 |
| 22 |                    4 |                 2 | 214092 |      100 |        1 |   214092 |         1 |                1 |
| 25 |                    4 |                12 |    150 |        0 |        1 |      150 |         1 |                1 |
| 28 |                    4 |             10000 |   1024 |        0 |        1 |     1024 |         1 |                1 |
| 31 |                    7 |                 0 |     76 |        0 |        1 |      228 |         1 |                3 |
| 34 |                    7 |                 1 | 772667 |    88064 |        1 |   772667 |         1 |                1 |
| 37 |                    7 |                 2 | 214092 |      100 |        1 |   214092 |         1 |                1 |
| 40 |                    7 |                12 |    150 |        0 |        1 |      150 |         1 |                1 |
| 43 |                    7 |             10000 |   1024 |        0 |        1 |     1024 |         1 |                1 |
+----+----------------------+-------------------+--------+----------+----------+----------+-----------+------------------+
```

### Nova scheduler
**1、Get allocation candidates**
- 调度一开始，调度器就回去查询每个计算节点的资源使用情况
- 调用如下API：
```
GET /allocation_candidates?resources=VCPU:4,DISK_GB:64,MEMORY_MB:2048
```
- curl模拟请求如下：
```json
# 申请token
openstack token issue | grep ' id' | awk '{print $4}'

# curl 调用 API
curl -g -i -X GET http://placement_ip:8778/placement/allocation_candidates?resources=DISK_GB:1,MEMORY_MB:512,VCPU:1 \
-H "User-Agent: python-novaclient" \
-H "Accept: application/json" \
-H "X-Auth-Token: $TOKEN" \
-H "OpenStack-API-Version: placement 1.10"

# 返回结果
HTTP/1.1 200 OK
Date: Thu, 22 Feb 2018 08:55:27 GMT
Server: Apache/2.4.6 (CentOS)
OpenStack-API-Version: placement 1.10
vary: OpenStack-API-Version,Accept-Encoding
x-openstack-request-id: req-234db1eb-1386-4e89-99bd-c9269270c603
Content-Length: 381
Content-Type: application/json

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
**2、Claim Resources**
- 在获取到 Allocation Candidates（即可用于资源分配的候选host）并经过过滤器过滤和权重计算之后，nova-scheduler开始尝试进行Claim resources
- 即在创建之前预先测试一下所指定的 host 的可用资源是否能够满足创建虚机的需求
- 调用如下API：
```json
PUT /allocations/{consumer_uuid}

request body
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

response body
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