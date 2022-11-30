---
title: keystone
date: 2022-11-20 12:23:49
tags:
---

### Keystone 的四种 Token
#### 四种 Token 的由来
- `D` 版本时，仅有 `UUID` 类型的 `Token`，`UUID token` 简单易用，却容易给 `Keystone` 带来性能问题，从上图的步骤 `4` 可看出，每当 `OpenStack API` 收到用户请求，都需要向 `Keystone` 验证该 `token` 是否有效。随着集群规模的扩大，`Keystone` 需处理大量验证 `token` 的请求，在高并发下容易出现性能问题。
- 于是 `PKI(Public Key Infrastructrue) token` 在 `G` 版本运用而生，和 `UUID` 相比，`PKI token` 携带更多用户信息的同时还附上了数字签名，以支持本地认证，从而避免了步骤 4。 因为 `PKI token` 携带了更多的信息，这些信息就包括 `service catalog`，随着 `OpenStack` 的 `Region` 数增多，`service catalog` 携带的 `endpoint` 数量越多，`PKI token` 也相应增大，很容易超出 `HTTP Server` 允许的最大 `HTTP Header`(默认为 8 KB)，导致 `HTTP` 请求失败。
- `PKIZ token` 就是 `PKI token` 的压缩版，但压缩效果有限，无法良好的处理 `token size` 过大问题。
- 前三种 `token` 都会持久性存于数据库，与日俱增积累的大量 `token` 引起数据库性能下降，所以用户需经常清理数据库的 `token`。为了避免该问题，社区提出了 `Fernet token`，它携带了少量的用户信息，大小约为 `255 Byte`，采用了对称加密，无需存于数据库中。

#### UUID
![uuid_token](https://raw.githubusercontent.com/com-wushuang/pics/main/uuid_token.png)
- `UUID token` 是长度固定为 32 Byte 的随机字符串，由 `uuid.uuid4().hex` 生成。
- 但是因 `UUID token` 不携带其它信息，`OpenStack API` 收到该 `token` 后，既不能判断该 `token` 是否有效，更无法得知该 `token` 携带的用户信息，所以需经图一步骤 4 向 `Keystone` 校验 `token`，**并获用户相关的信息**。
- `UUID token` 简单美观，不携带其它信息，因此 `Keystone` 必须实现 `token` 的存储和认证，随着集群的规模增大，`Keystone` 将成为性能瓶颈。

#### PKI
![pki_token](https://raw.githubusercontent.com/com-wushuang/pics/main/pki_token.png)
- `PKI` 的本质就是基于数字签名，`Keystone` 用私钥对 `token_data` 进行数字签名生成 `token`，各个 `API server` 用公钥在本地验证该 `token`。
- 各个 `API server` 解开 `token` 后就可以拿到用户相关信息。`token_data` 如下:
````json
{
  "token": {
    "methods": [ "password" ],
    "roles": [{"id": "5642056d336b4c2a894882425ce22a86", "name": "admin"}],
    "expires_at": "2015-12-25T09:57:28.404275Z",
    "project": {
      "domain": { "id": "default", "name": "Default"},
      "id": "144d8a99a42447379ac37f78bf0ef608", "name": "admin"},
    "catalog": [
      {
        "endpoints": [
          {
            "region_id": "RegionOne",
            "url": "http://controller:5000/v2.0",
            "region": "RegionOne",
            "interface": "public",
            "id": "3837de623efd4af799e050d4d8d1f307"
          },
          ......
      ]}],
    "extras": {},
    "user": {
      "domain": {"id": "default", "name": "Default"},
      "id": "1552d60a042e4a2caa07ea7ae6aa2f09", "name": "admin"},
    "audit_ids": ["ZCvZW2TtTgiaAsVA8qmc3A"],
    "issued_at": "2015-12-25T08:57:28.404304Z"
  }
}
````
#### PKIZ
`PKIZ` 在 `PKI` 的基础上做了压缩处理，但是压缩的效果极其有限，一般情况下，压缩后的大小为 `PKI token` 的 `90 %` 左右，所以 `PKIZ` 不能友好的解决 `token size` 太大问题。

#### Fernet
![fernet_token](https://raw.githubusercontent.com/com-wushuang/pics/main/fernet_token.png)
- 用户可能会碰上这么一个问题，当集群运行较长一段时间后，访问其 `API` 会变得奇慢无比，究其原因在于 `Keystone` 数据库存储了大量的 `token` 导致性能太差，解决的办法是经常清理 `token`。
- 为了避免上述问题，社区提出了`Fernet token`，它采用对称加的方式加密 `token_data`。
- `Fernet` 是专为 `API token` 设计的一种轻量级安全消息格式，不需要存储于数据库，减少了磁盘的 `IO`，带来了一定的性能提升。为了提高安全性，需要采用 `Key Rotation` 更换密钥。

#### 总结
|Token 类型|UUID|PKI|PKIZ|Fernet|
|---- | ---- | ---- | ---- | ---- |
|大小|32 Byte|KB 级别|KB 级别|约 255 Byte|
|支持本地认证	|不支持|	支持	|支持|不支持|
|Keystone 负载|大|小|小|大|
|存储于数据库|是|是|是|否|
|携带信息|无|user、catalog 等|user、catalog 等|user 等|
|涉及加密方式|无|非对称加密|非对称加密|对称加密(AES)|
|是否压缩|否|	否|是|否|
|版本支持|D|G|J|K|

#### 如何选择 Token
`Token` 类型的选择涉及多个因素，包括 `Keystone server` 的负载、`region` 数量、安全因素、维护成本以及 `token` 本身的成熟度。`region` 的数量影响 `PKI/PKIZ token` 的大小，从安全的角度上看，`UUID` 无需维护密钥，`PKI` 需要妥善保管 `Keystone server` 上的私钥，`Fernet` 需要周期性的更换密钥，因此从安全、维护成本和成熟度上看，`UUID > PKI/PKIZ > Fernet` 如果：
- Keystone  负载低，region 少于 3 个，采用 UUID token。
- Keystone  负载高，region 少于 3 个，采用 PKI/PKIZ token。
- Keystone  负载低，region 大与或等于 3 个，采用 UUID token。
- Keystone  负载高，region 大于或等于 3 个，K 版本及以上可考虑采用 Fernet token。