---
title: 什么是API Gateway？
date: 2020-11-26 18:06:13
tags:
---
## 微服务架构存在的问题

在微服务架构中，有多个服务在运行，每个服务都是针对系统的特定的组件而设计的。当客户端（移动应用程序，Web应用程序或第三方应用程序）直接与这些微服务通信时，就会出现许多问题：

![没有网关的微服务架构](https://github.com/com-wushuang/pics/blob/main/%E6%B2%A1%E6%9C%89%E7%BD%91%E5%85%B3%E7%9A%84%E5%BE%AE%E6%9C%8D%E5%8A%A1%E6%9E%B6%E6%9E%84.png)

1. 微服务提供的API的粒度通常与客户端需要的粒度不同。微服务API本质上非常通用且粗糙，仅返回一部分功能数据。客户端的单个操作可能需要调用多个服务。这可能导致客户端和服务器之间进行多次往返网络调用，从而增加了显着的延迟。
2. 对于不同类型的客户端，网络性能有所不同，例如移动网络速度较慢且延迟较高。 WAN比LAN慢。来自客户端的多个网络请求会产生不一致的体验。
3. 这可能会导致复杂的客户端代码。客户端需要调用多个端点（主机和端口）并整合数据，同时还要用合适的方式处理服务故障。
4. 它还在客户端和后端之间建立了紧密的耦合。客户需要知道如何分解单个功能。添加新服务或重构现有服务变得更加困难。
5. 每个面向客户的服务必须实现通用功能，例如授权和身份验证，SSL，API速率限制，访问控制等。
6. 服务必须仅使用客户端友好的协议，例如HTTP或WebSocket。这限制了服务通信协议的选择。

## API网关的意义

API网关可以帮助解决这些挑战。它使客户端与微服务解耦。 API网关位于客户端和服务之间，并且是所有客户端请求的单个入口点。它接收来自客户端的所有请求，然后通过请求路由，组合和协议转换将它们路由到适当的微服务。

![api网关](https://github.com/com-wushuang/pics/blob/main/api%E7%BD%91%E5%85%B3.png)

通常，它通过调用多个服务并汇总结果并将其发送回客户端来处理请求。 API网关具有以下优点：

1. 将客户端与微服务隔离，网关完成服务发现功能。
2. API网关可以将多个单独的请求聚合为一个请求。当单个用户操作需要调用多个后端服务时，客户端只需要向网关发送一个请求。网关将请求分派到各种后端服务，然后汇总结果并将其发送回客户端。这有助于减少客户端与后端之间的交互次数。
3. 通过避免客户端和服务器之间的多次往返，它还提高了客户端性能和用户体验。同样，API网关进行的多次调用在同一网络中，其性能要比从客户端执行的性能更高。
4. 通过将调用多个服务的逻辑从客户端转移到API网关，简化了客户端。
5. 可以将标准的Web API协议转换为内部使用的任何协议。
6. 网关可用于从单个服务中卸载通用功能，将这些功能整合到网关中而不是让每个服务负责实现它们。对于那些需要专业领域知识才能正确实现的功能（例如身份验证和授权）尤其如此。可以卸载的功能是：

- SSL termination（SSL 卸载）
- 请求重试、熔断、QoS
- 服务发现
- 认证和鉴权
- IP 黑白名单
- 流量管控
- 日志、监控、追踪
- 请求缓存

缺点：

网关会带来系统复杂性的提升，API网关本身也需要开发、部署、管理。同时，由于增加了网络转发次数，因此也增加了响应时间。同时，API网关有可能成为系统的瓶颈。

# API Gateway Pattern

相比于单个API网关的架构，有一种多个网关的架构模式，它为不同的客户端提供不同的网关。这样的目的是根据客户端的需求提供量身定制的API，从而避免为所有客户端提供通用API造成的代码大量膨胀。

![多网关架构](https://github.com/com-wushuang/pics/blob/main/%E5%A4%9A%E7%BD%91%E5%85%B3%E6%9E%B6%E6%9E%84.png)

## 著名的API Gateway

### Netflix API Gateway：Zuul

Netflix的流媒体服务可在超过1000种不同的设备类型（电视，机顶盒，智能手机，游戏系统，平板电脑等）上使用，在高峰时段每秒处理50,000个请求，使用单个api网关架构存在巨大的局限性，因此他们采用了如下的架构，为每类设备量身定制API网关。

Netflix的Zuul 2是所有进入Netflix云基础架构的请求的front door。 Zuul 2大大改进了架构和功能，使得网关能够处理，路由和保护Netflix的云系统，并帮助为1.25亿会员提供最佳体验。

![zuul网关](https://github.com/com-wushuang/pics/blob/main/zuul%E7%BD%91%E5%85%B3.png)

### Amazon API Gateway

AWS提供了用于创建，发布，维护，监控和保护REST，HTTP和WebSocket的完全托管服务，开发人员可以在其中创建用于访问AWS或其他Web服务的API以及存储在AWS Cloud中的数据。

![aws网关](https://github.com/com-wushuang/pics/blob/main/aws%E7%BD%91%E5%85%B3.png)

### Kong API Gateway

Kong Gateway是为微服务优化的开源，轻量级API网关，可提供无与伦比的延迟性能和可伸缩性。如果您只需要基础，kong是非常适合的。通过添加更多节点，可以轻松地水平扩展它。它以非常低的延迟支持大量可变的工作负载。

![kong网关](https://github.com/com-wushuang/pics/blob/main/kong%E7%BD%91%E5%85%B3.png)

### 其他的 API Gateways

- [Apigee API Gateway](https://apigee.com/api-management/)
- [MuleSoft](https://www.mulesoft.com/platform/api-management)
- [Tyk.io](https://github.com/TykTechnologies/tyk)
- [Akana](https://www.akana.com/products/api-platform/api-gateway)
- [SwaggerHub](https://swagger.io/tools/swaggerhub/)
- [Azure API Gateway](https://azure.microsoft.com/en-us/services/api-management/)
- [Express API Gateway](https://www.express-gateway.io/)
- [Karken D](https://www.krakend.io/)

### 如何选择？

评估标准包括简单性，开源与专有性，可伸缩性和灵活性，安全性，功能，社区，管理（支持，监控和部署），环境配置（安装，配置，托管），价格和文档。

# API 聚合

API网关的有些请求可以直接映射到单个微服务的API。但是，大多数情况下，完成一个具有完整功能的请求需要网关调用多个微服务，这时需要将各个微服务的请求结果聚合。于是，很多网关实现中，存在一个聚合层，也就是backend for frontend（文末会有相关的参考资料）。

给网关附加太多的功能会导致网关变得非常臃肿，以至于难以测试和部署。强烈建议避免API网关中的聚合和数据转换。 Netflix API Gateway , Zuul 2从他们在Zuul到原始系统的网关中删除了许多业务逻辑。有关更多详细信息，[请参阅此处](https://www.infoq.com/news/2016/10/netflix-zuul-asynch-nonblocking/)。

针对如上问题，引入了api聚合层的微服务架构如下：

![引入了聚合层的微服务架构](https://github.com/com-wushuang/pics/blob/main/%E5%BC%95%E5%85%A5%E4%BA%86%E8%81%9A%E5%90%88%E5%B1%82%E7%9A%84%E5%BE%AE%E6%9C%8D%E5%8A%A1%E6%9E%B6%E6%9E%84.png)

# Service Mesh 和 API Gateway

服务网格提供了许多功能，例如：

- 负载均衡
- 服务发现
- 健康检查
- 安全

从表面上看，API网关和服务网格似乎解决了相同的问题，会被认为是冗余。它们确实解决了相同的问题，但是在不同的情况下。 API网关被部署为业务解决方案的一部分，该业务解决方案可由处理南北向流量的外部客户端（面对外部客户端）发现，但是，服务网格可以处理东西向流量（在不同的微服务之间）。

采用服务网格可免除在业务代码中加入和业务不想关的代码，这些都将由服务网格来实现，熔断机制，服务发现，健康检查、服务监控（流量、tracing、性能）。对于少量的微服务，不宜采用服务治理技术，因为服务网格本身的管理会带来系统的复杂度。但是，对于存在大量的微服务的系统，这将是有益的。

结合这两种技术可能是一种最佳实践，架构图如下：

![服务治理结合网关技术](https://github.com/com-wushuang/pics/blob/main/%E6%9C%8D%E5%8A%A1%E6%B2%BB%E7%90%86%E7%BB%93%E5%90%88%E7%BD%91%E5%85%B3%E6%8A%80%E6%9C%AF.png)

# 参考资料

1. https://microservices.io/index.html
2. https://docs.microsoft.com/en-us/azure/architecture/
3. https://github.com/wso2/reference-architecture/blob/master/api-driven-microservice-architecture.md
4. https://tsh.io/blog/design-patterns-in-microservices-api-gateway-bff-and-more/
5. https://www.infoq.com/articles/service-mesh-ultimate-guide/
6. https://samnewman.io/patterns/architectural/bff/
7. https://netflixtechblog.com/
8. https://philcalcado.com/2015/09/18/the_back_end_for_front_end_pattern_bff.html