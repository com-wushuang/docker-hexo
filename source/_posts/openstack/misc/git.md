---
title:  git
date: 2023-02-03 15:18:17
tags:
categories: OpenStack
---

## git 如何打patch

### 创建 patch

1、某次提交（含）之前的几次提交的patch
```shell
# n指从对应的commit开始算起n个提交
git format-patch <commit-id> -n
```

2、某个提交的patch
```shell
git format-patch <commit-id> -1
```
3、patch创建成功后，会有一个patch文件

### 应用 patch
1、查看patch文件状态
```shell
git apply --stat newpatch.patch
```
2、检查patch是否能正常打入
```shell
git apply --check newpatch.patch
```
3、打入patch
```shell
git apply newpatch.patch
```