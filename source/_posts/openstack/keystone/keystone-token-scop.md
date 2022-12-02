---
title: Keystone token的scope
date: 2022-11-20 12:23:49
tags:
categories: OpenStack
---

### 为什么需要 token scope

`token` 是用来传递用户的认证信息的，用户认证信息的一个关键是的角色。在 `openstack` 中用户的角色往往不止一个、用户可能在不同的 `project` 中，所以 `scope-token` 就显得十分必要。在这种机制下，`openstack` 给 `token` 加上了 `scope`。例如，某一个`project scope` 的 `token` 不能被重用于其他 `project`。

### Unscoped tokens

一种特殊的 `token` ，不包含 `service catalog`、`roles`、`authorization scope`（`project`、`domain`、`system`属性）。你可以使用它向 `keystone` 证明你的身份，以此来换取 `scoped-tokens`。这就是最主要的用法了。

必须满足如下条件，`keystone` 才会返回 `unscoped token`：
- 在认证请求中没有指定任何 `authorization scope`（例如：在命令中未包含 `--os-project-name` 或 `--os-domain-id` ）
- 没有在 `default` 下

**获得一个unscoped token:**
```shell
curl -i \
  -H "Content-Type: application/json" \
  -d '
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "id": "default" },
          "password": "adminpwd"
        }
      }
    }
  }
}' \
  "http://localhost:5000/v3/auth/tokens" ; echo
```

**以 token 换取 token（如上所述一般用unscope token 换取 scope token）:**

```shell
curl -i \
  -H "Content-Type: application/json" \
  -d '
{ "auth": {
    "identity": {
      "methods": ["token"],
      "token": {
        "id": "'$OS_TOKEN'"
      }
    }
  }
}' \
  "http://localhost:5000/v3/auth/tokens" ; echo
```


### Project-scoped tokens

`project` 是资源的容器（例如，`instance`、`volume`）。`Project-scoped tokens` 包含了 `service catalog`、`roles`、`project info` 等信息，`Project-scoped tokens` 表示授权被限定在特定租户中。大部分终端用户需要将 `role assignment` 到 `project` 下以此来消费租户中的资源。

**获取一个 project-scoped token：**
```shell
curl -i \
  -H "Content-Type: application/json" \
  -d '
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "id": "default" },
          "password": "adminpwd"
        }
      }
    },
    "scope": {
      "project": {
        "name": "admin",
        "domain": { "id": "default" }
      }
    }
  }
}' \
  "http://localhost:5000/v3/auth/tokens" ; echo
```

### Domain-scoped tokens

`Domain` 是 `projects`、`users`、`groups`的命名空间。`Domain-scoped tokens` 用来代表操作 `domain` 下资源时的权限。尽管其他的组件很少涉及到 `domain` 的概念，但是 `keystone` 组件是运用 `domain` 概念最多的地方，因为 `user` 管理、 `project` 管理功能都是在 `keystone` 去实现的，而 `user` 、 `project` 等资源都属于 `domain` ，因此为了权限控制，`Domain-scoped tokens` 常常用在 `keystone` 中。例如： `domain` 管理员能够在该 `domain` 中创建新 `user` 、创建新 `project` 。 `Domain-scoped tokens` 包含了 `service catalog`、`roles`、`domain info`等信息。

**获取一个 domain-scoped token：**
```shell
curl -i \
  -H "Content-Type: application/json" \
  -d '
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "id": "default" },
          "password": "adminpwd"
        }
      }
    },
    "scope": {
      "domain": {
        "id": "default"
      }
    }
  }
}' \
  "http://localhost:5000/v3/auth/tokens" ; echo
```

### 说明

- 1.获取token接口的返回信息没有列出，可参考官方api文档。对于不同的 scope 返回的结果，token中包含的信息也是不同的。

- 2.返回的 header 中，X-Subject-Token 就是token的 ID，请求其他服务时，使用的也是这个值。

### Token的用处
- 用 `REST API` 方式请求其他服务，在请求头带上  `X-Auth-Token:Token_ID`
- 验证 `token` 的有效性，获得 `token` 中的信息(`domain`、`project`、`role`、`endpoint`)
- 换取其他的 `token`（一般为不同的 `scope` ）
- 吊销 `token`
