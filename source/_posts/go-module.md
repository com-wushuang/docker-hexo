---
title: go module
date: 2020-12-29 10:22:21
tags:
categories: go
---

## 前言

go module 学习最主要的参考资料就是官方文档，这篇文章是笔记，而不是教程。在it领域最高效的学习方法就是看官方的文档，看源代码，没有之一。今后我所有的文章都将写成笔记的性质，教程不过都是官方文档的翻译。https://github.com/golang/go/wiki/Modules

## 工作流

日常工作流：

- 代码中 import 导入申明
- go build 和 go test 命令会更新 go.mod文件并下载新依赖
- 有必要时，你可以直接修改文件go.mod文件以指定依赖的版本号；`go get foo@v1.2.3` 、`go get foo@master` 、`go get foo@e3702bed2`命令也可以选择指定版本的依赖

一些有用的command：

- `go list -m all` — 列出项目所有的依赖（直接或间接）
- `go list -u -m all` — 列出所有可升级的依赖（直接或间接）
- `go get -u ./...` or `go get -u=patch ./...` (在module的根目录执行) — 将依赖升级到最新版本
- `go build ./...` or `go test ./...` (在module根目录执行) — 编译和测试module
- `go mod tidy` — 清理依赖

## 场景

### 新建module

### Adding a dependency

### Upgrading dependencies

### Adding a dependency on a new major version

### Upgrading a dependency to a new major version



