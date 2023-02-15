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

### 撤销 patch
```
git apply -R newpatch.patch
```

## git 修改某次 commit 内容
1、将当前分支无关的工作状态进行暂存
```
git stash
```
2、将 HEAD 移动到需要修改的 commit 上
```
git rebase commit-id^ --interactive
```
3、找到需要修改的 commit ，将首行的 pick 改成 edit
4、进行修改
5、将改动文件添加到暂存
```
git add 
```
6、 追加改动到提交
```
git commit –amend
```
7、 移动 HEAD 回最新的 commit
```
git rebase –-continue
```

## git 合并 commit
1、当前共有3次提交，把这3次提交合并为一次
2、`git rebase -i HEAD~3`
3、进入交互模式，把除了第一行外的`pick`改成`s`
4、`wq`保存退出
5、处理提交注释，默认情况下，是把三条 `commit message` 合并为一条，当然你也可以自行修改
