---
title: cors
date: 2021-01-14 16:31:50
tags:
---

跨源HTTP请求的一个例子：运行在 `http://domain-a.com` 的JavaScript代码使用[`XMLHttpRequest`](https://developer.mozilla.org/zh-CN/docs/Web/API/XMLHttpRequest)来发起一个到 `https://domain-b.com/data.json` 的请求。

出于安全性，浏览器限制脚本内发起的跨源HTTP请求。 XMLHttpRequestI遵循同源策略，这意味着使用这些API的Web应用程序只能从加载应用程序的同一个域请求HTTP资源，除非响应报文包含了正确CORS响应头。

## 简介

**跨源资源共享**是一种基于[HTTP](https://developer.mozilla.org/zh-CN/docs/Glossary/HTTP) 头的机制，该机制通过允许服务器标示除了它自己以外的其它[origin](https://developer.mozilla.org/zh-CN/docs/Glossary/源)（域，协议和端口），这样浏览器可以访问加载这些资源。CORS需要浏览器和服务器同时支持。目前，所有浏览器都支持该功能。整个CORS通信过程，都是浏览器自动完成，不需要用户参与。对于开发者来说，CORS通信与同源的AJAX通信没有差别，代码完全一样。浏览器一旦发现AJAX请求跨源，就会自动添加一些附加的头信息，有时还会多出一次附加的请求，但用户不会有感觉。**因此，实现CORS通信的关键是服务器。只要服务器实现了CORS接口，就可以跨源通信。**

![跨域请求示例](CORS_example.png)

