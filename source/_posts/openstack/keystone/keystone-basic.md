 
## Domain，Project，User，Role，Token 的概念和关系
![keystone用户体系](https://raw.githubusercontent.com/com-wushuang/pics/main/keystone%E7%94%A8%E6%88%B7%E4%BD%93%E7%B3%BB.png)

- Domain：是 `project` ， `user` ， `group` 的 `namespace` 。 一个 `domain` 内，这些元素的名称不可以重复，但是在两个不同的`domain` 内，它们的名称可以重复。因此，在确定这些元素时，需要同时使用它们的名称和它们的 `domain` 的 `id` 或者 `name`。
- Project：是资源的集合，其中有一类特殊的 `project` 是 `admin project`。通过指定 `admin_project_domain_name` 和 `admin_project_name` 来确定一个 `admin project`，然后该 `admin project` 中的 `admin` 用户即是 `cloud admin`。
- Group：是一个 `domain` 部分 `user` 的集合，其目的是为了方便分配 `role`。给一个 `group` 分配 `role`，结果会给 `group` 内的所有 `users` 分配这个 `role`。
- Role：
    - 是全局的，因此其名称必须唯一。`role` 的名称没有意义，其意义在于 `policy.json` 文件根据 `role` 的名称所指定的允许进行的操作。
    - 简单地，`role` 可以只有 `admin` 和 `member` 两个，前者表示管理员，后者表示普通用户。但是，结合 `domain` 和 `project` 的限定，`admin` 可以分为 `cloud admin`，`domain admin` 和 `project admin`。
    - `policy.json` 文件中定义了 `role` 对某种类型的资源所能进行的操作，比如允许 `cloud admin` 创建 `domain` ，允许所有用户创建卷等。
- Token：具有 `scope` 的概念，分为 `unscoped token`，`domain-scoped token` 和 `project-scoped token`。

## 用户管理
### 用户的域
`user` 不是一个全局的概念，它是属于 `domain` 下的资源，也就是说 `user` 一定要属于某一个 `domain` 。这一点和 `role` 不同，`role` 是全局的。

### 用户的角色
没有任何权限的 `user` 是没有意义的，而 `openstack` 权限控制模型是 `RBAC` ，因此，`user` 需要被赋予某些角色，才能够获角色拥有的权限。

### 用户赋予角色
`user` 被赋予 `role` 的这个操作，在 `openstack` 中被称为 `role assignment` ， `assign` 动作一般会指定一个域也就是 `domain` 或者 `project` ，因此也就衍生出了` token scope` 的问题，这个后面会讲。一个 `role assignment` 的例子：

```shell
openstack role add --project acme --user alice compute-user # 给 alice用户赋予了 compute-user 这个角色，域是project acme
```

简单来说就是：给 `alice` 在 `acme` 这个 `project` 下赋予了`compute-user` 这个角色。

### 用户多角色
一个 `user` 在不同的 `project` 中有不同的角色。例如，`Alice` 在拥有上述角色的同时，也可以是 `project1` 的 `admin` 角色，这并不冲突。甚至，`user` 在相同的 `project` 下可以同时拥有很多角色。

## 权限控制

### 原理
- `role` 的所有权限信息，都定义在 `/etc/[SERVICE_NAME]/policy.yaml` 文件下。
- 简单来说，这些文件描述了系统中的各个 `role` 能做什么。
- 每一个服务基本上都会有一个这样的文件，因此系统中的所有 `policy.yaml` 文件描述了各种 `role` 能对系统的各个服务所管理的资源做什么操作（请求什么 `api` ）。
- 例如，`/etc/nova/policy.yaml` 指定了计算服务的准入策略、`/etc/glance/policy.yaml` 指定了镜像服务的准入策略。

### 默认角色
`openstack` 系统中默认的角色只有两个 `admin` 和 `member`，尽管 `keystone` 支持创建角色，但是如果想要对该角色的权限做定义，那么还需要修改 `policy.json` 文件。

### 例子
可以通过一个例子理解一下 `openstack` 是如何通过角色进行权限控制的。
- 首先，已知 `/etc/cinder/policy.yaml` 中有一条默认的权限策略如下：
```json
"volume:create": "",
```
- 这条策略表示，所有的创建 `volume` 的操作都允许。
- 假如，想要控制只有某个特定角色（假如是`compute-user`）的用户才能创建 `volume` ，面对这种需求，你需要这么做。
- 第一：在 `keystone` 创建 `compute-user` 这个角色；
- 第二：将 `cinder` 组件的 `/etc/cinder/policy.yaml` 文件修改如下：
```json
"volume:create": "role:compute-user",
```

## 服务管理
`keystone` 还实现了服务发现和服务注册的功能，查看 `keystone` 中注册的服务
```shell
openstack service list
```

查看服务的 `Endpoint`
```shell
openstack endpoint list
```

## 用户组管理

用户组是用户的集合，一般用来快速给组内用户分配角色。因为如果给用户组赋予某个角色，那么该组下的所有用户都被赋予了相应的角色。


