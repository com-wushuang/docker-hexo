---
title: oauth
date: 2021-01-08 15:18:48
tags:
categories: 认证
---

## Hydra

### 简介

定位：

- OAuth2 Provider：enable third-party solutions to access to your APIs
- OpenID Connect ：be an Identity Provider like Google, Facebook, or Microsoft
- enable your browser, mobile, or wearable applications to access your APIs，You don't have to store passwords on the device and can revoke access tokens at any time
- you can limit what type of information your backend services can read from each other

限制：

- 没有用户管理功能
- ORY Hydra doesn't support the OAuth 2.0 Resource Owner Password Credentials flow

### Oauth2.0

你的照片存储在社交网站上。现在你想要通过第三方的打印服务去打印你的照片，没有oauth，你就必须把你的社交网站的账号和密码告诉第三方的打印服务，这显然是不合理的。

有了oauth，你能够委托给打印服务相应的权限（读取你的照片，而不读取你的联系人），客户端不再用账号和密码作为凭证来获取你的照片，而是access_token。

#### 术语

1. resource owner：授权给第三方应用访问你的账户的用户，也叫最终用户，例如：你本人
2. OAuth 2.0 Authorization Server ：实现了oauth2.0协议的服务器，例如：hydra
3. resource provider：资源服务器，例如社交网站的服务器
4. OAuth 2.0 Client：第三方应用，想要访问用户的资源
5. Identity Provider：身份提供商，提供用户的注册，登录，修改密码等功能，例如：keystone
6. User Agent：一般指服务器
7. OpenID Connect：是一种协议，建立在oauth2.0之上，仅仅用来认证

#### workflow

1. 注册客户端
2. 应用请求用户授权访问其数据
3. 用户被重定向到Authorization Server
4. Authorization Server确认用户（认证），请求用户授予应用相关权限
5. Authorization Server签发tokens，应用利用该token作为凭证访问用户数据

#### OAuth 2.0 Scope

The scope of an OAuth 2.0 token defines the permission the token was granted by the end-user.

hydra预定义了两种scope值：

- offline_access：refresh token模式
- openid：openid模式

#### OAuth 2.0 Access Token Audience

The Audience of an Access Token refers to the Resource Servers that this token is intended for.

audience通常是一些urls：

- `https://api.mydomain.com/blog/posts`
- `https://api.mydomain.com/users`
- `https://api.mydomain.com/tenants/foo/users`

#### OAuth 2.0 Token Introspection

OAuth2 Token Introspection 是 [IETF](https://tools.ietf.org/html/rfc7662) 标准。它定义了一种方法，通过该方法能够从OAuth 2.0 authorization server查询出token是否有效和token的元数据信息。

#### OAuth 2.0 Refresh Tokens

刷新acess_token

### OpenID Connect

#### workflow

OpenID Connect的工作流和oauth2.0非常的相似。它最典型的应用场景是实现 "Login with <Google|Facebook|Hydra>" 

使用OpenID Connect：

1.在oauth2.0的工作流的scope中加入openid，如下：

```http
https://my-hydra/oauth2/auth?client_id=...&response_type=code&scope=openid
```

2.用授权码换取token：

```http
POST /oauth/token HTTP/1.1
Host: my-hydra

grant_type=authorization_code
&code=xxxxxxxxxxx
&redirect_uri=https://example-app.com/redirect
&client_id=xxxxxxxxxx
&client_secret=xxxxxxxxxx
```

3.返回体中会附带ID Token

```javascript
{
  "access_token": "MTQ0NjJkZmQ5OTM2NDE1ZTZjNGZmZjI3",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "IwOGYzYTlmM2YxOTQ5MGE3YmNmMDFkNTVk",
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFlOWdkazcifQ.ewogImlzcyI6ICJodHRwOi8vc2VydmVyLmV4YW1wbGUuY29tIiwKICJzdWIiOiAiMjQ4Mjg5NzYxMDAxIiwKICJhdWQiOiAiczZCaGRSa3F0MyIsCiAibm9uY2UiOiAibi0wUzZfV3pBMk1qIiwKICJleHAiOiAxMzExMjgxOTcwLAogImlhdCI6IDEzMTEyODA5NzAKfQ.ggW8hZ1EuVLuxNuuIJKX_V8a_OMXzR0EHR9R6jgdqrOOF4daGU96Sr_P6qJp6IcmD3HP99Obi1PRs-cwh3LO-p146waJ8IhehcwL7F09JdijmBqkvPeB2T9CJNqeGpe-gccMg4vfKjkM8FcGvnzZUN4_KSP0aAp1tOJ1zZwgjxqGByKHiOtX7TpdQyHE5lcMiKPXfEIQILVq0pc_E2DzL7emopWoaoZTF_m0_N0YzFC6g6EJbOEoRoSK5hoDalrcvRYLSrQAZZKflyuVCyixEoV9GfNQC3_osjzw2PAithfubEEBLuVVk4XUVrWOLrLl0nx7RkKU8NXNHq-rvKMzqg",
  "scope": "openid"
}
```

4.ID Token的目的仅仅是在OAuth2 Client Application中用作认证。他并不具有会话管理的功能，他仅仅一个用户的凭证。

### Login Flow

#### Initiating the OAuth 2.0 / OpenID Connect Flow

```html
<a href="https://<hydra-public>/oauth2/auth?client_id=...&response_type=...&scope=...">
  Login in with ORY Hydra</a>
```

state参数适用来防止csrf攻击

#### Login Sessions

Hydra会跟踪用户的session。hydra会给客户端生成一个cookie，cookie包含了用户的userID。在OAuth2 / OpenID Connect 流程中，hydra根据用户的session来决定不同的业务流程，例如，一个认证过的用户不再需要向其展示登录界面。

Hydra 支持如下的查询参数:

- prompt
  - prompt=none：指示Hydra不向用户展示login和consent界面。用来检测用户的登录和授权状态。如果未认证这回返回错误信息和错误描述
  - prompt=login：指示hydra强制让用户登录重新认证
  - prompt=consent：指示hydra强制让用户授权
- max_age：认证的有效时间，在有效时间内，用户不需要再认证，当超过了有效时间，用户需要重新认证

#### Login endpoint

使用hydra需要实现一个登录界面，login endpoint的url通过配置文件配置。采用什么样的认证后端取决于你，因为hydra是没有用户管理功能的，不负责认证。用户输入完账户密码后，服务端就对其进行认证，认证成功后，向hydra发送如下请求以接受或者拒绝登录请求。



