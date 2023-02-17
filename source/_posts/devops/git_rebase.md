---
title:  git rebase
date: 2023-02-03 15:18:17
tags:
categories: OpenStack
---

## rebase 是干嘛的

- `rebase` 官方解释为变基,可以理解为移动你的分支根节点,维护一个更好的提交记录。
- `rebase` 把你当前最新分支与其他分支合并时候,会把其他分支的提交记录放在我们当前分支时间线最开始的位置。也就是说,会把我们的提交记录整合在公共分支的后面。
- 简单来讲,合并本地其他分支 为了不产生多余的分叉,及合并记录时可以使用`rebase`。

## rebase 与 merge 的差异

- `rebase` 会把你当前分支的 `commit` 放到公共分支的最后面,所以叫变基。就好像你从公共分支又重新拉出来这个分支一样。
- `merge` 会把公共分支和你当前的 `commit` 合并在一起，形成一个新的 `commit` 提交。

## 应用场景

- 你刚入公司，技术leader让你以 `master` 分支为基础,拉出一个分支进行开发需求。此时 `master` 分支提交记录为 `a、b`。你在 `dev` 分支分别 `commit` 了2次记录为 `e、f` ,有其他同事在 `master` 分支提交了两次记录为 `c、d` 这个时候你要合并 `master` 分支代码。


- 当前分支状态节点如下图所示:

![git_rebase_1](https://raw.githubusercontent.com/com-wushuang/pics/main/git_rebase_1.png)

## 使用 git merge 进行合并操作
```shell
  $ git merge master  // 合并master分支代码
  $ git log --graph --oneline // 查看log点线图
  
  # 符号解释:
  * 表示一个commit， 注意不要管*在哪一条主线上 
  | 表示分支前进 
  / 表示分叉 
  \ 表示合入
```
![git_rebase_2](https://raw.githubusercontent.com/com-wushuang/pics/main/git_rebase_2.png)

## 结论
- 如上图所示 `merge` 会把两个分支合并在一起，形成一个新的 `commit` 提交记录
- 我们发现 `coomit` 提交记录是把合并的分支记录放到我们当前 `dev` 分支记录的后面
- 并且 `coomit` 提交记录会产生分叉



## 使用 git rebase 进行合并操作
```shell
  $ git rebase master  // 合并master分支代码
  $ git log --graph --oneline // 查看log点线图
```
![git_rebase_3](https://raw.githubusercontent.com/com-wushuang/pics/main/git_rebase_3.png)
## 结论
- 首先，我们发现目前 `dev` 分支上面的提交记录为 `abcdef` 并没有像 `merge` 一样产生新的提交记录
- 其次 `rebase master` 分支到 `dev` 分支, `dev` 分支的历史记录会添加在 `master` 分支的后面
- 如图所示，历史记录成一条线,非常整洁,最后并没有像使 `merge` 一样提交记录产生分叉




## rebase 的使用业务场景

**场景一**

经典场景,优化本地提交记录,使其减少分叉。

**场景二**

连续性冲突

- 此时你从 `master` 分支拉出一个dev分支来对以v1版本为基础a功能进行需求更改，由于项目经理分功能时,让你的同事也对 `master` 分支中的 `a` 功能中的某个公共页面 `a` 也进行了整改,过一会你同事改完,提交 `x` 版本并合并 `push` 到了 `master` 远程分支上面
- 此时我们在 `dev` 分支完成一次开发提交了 `v2` 版本
- 产品经理过来说,需求有变更,要再做修改,然后我们又以 `v2` 的基础上在做修改,并提交为 `v3` 版本
- 过一会测试又提了一个需求建议。我们接着以当前dev分支 `v3` 版本为基础做好了整改并 `commit` 一个 `v4` 版本
- 到此我们本地假设对页面 `a` 修改了三次。同事修改了一次,并 `push` 到了远程 `master` 上面。那么我们对 `master` 分支进行合并到时候就会产生冲突

- 简单来讲就是。远程分支 `master` 对文件 `a` 进行了 1 次 `commit` ，而别的分支 `dev` 对文件 `a` 进行了 3 次 `commit`，但是本地分支 `dev` 提交的 `n` 次 `commit` 都与 `master` 分支的 1 次 `commit` 有冲突

使用 git rebase 解决冲突
```shell
$ git fetch  # 更新本地存储的远程仓库的分支引用
$ git rebase origin/master # 拉去远程分支master中的代码与当前分支合并且变基
# 此时我们会产生第一次冲突,为当前dev分支版本v2中的a页面与远程分支master中的a页面冲突。解决后,根据提示进行 
$ git add .
$ git rebase continue # 继续进行合并
# 此时我们会产生第二次冲突,为当前dev分支版本v3中的a页面与远程分支master中的a页面冲突。解决后,根据提示进行 
$ git add .
$ git rebase continue # 继续进行合并
# 此时我们会产生第三次冲突,为当前dev分支版本v4中的a页面与远程分支master中的a页面冲突。解决后,根据提示进行 
$ git add .
$ git rebase continue # 继续进行合并
# 至此我们使用 rebase 变基完成 可以根据产品需求push到远程dev分支
$ git log --graph --oneline # 查看log点线图
```
结论

- 不会因为像使用 `merge` 时合代码时遇到冲突产生新的提交记录
- 用 `merge` 只需要解决一次冲突即,简单粗暴,而用 `rebase` 的时候 ，需要依次解决每次的冲突，才可以提交。
- 使用 `rebase` 提交记录不会分叉,一条线干净整洁
- 冲突解决完之后，使用 `git add` 来标记冲突已解决，最后执行`git rebase --continue` 继续。如果中间遇到某个补丁不需要应用，可以用下面命令忽略：`git rebase --skip`
- 如果想回到 `rebase` 执行之前的状态，可以执行：`git rebase --abort`

**场景三**

git 合并 commit

- 当前共有3次提交，把这3次提交合并为一次
- `git rebase -i HEAD~3`
- 进入交互模式，把除了第一行外的`pick`改成`s`
- `wq`保存退出
- 处理提交注释，默认情况下，是把三条 `commit message` 合并为一条，当然你也可以自行修改

**场景四**

git 修改某次 commit 内容

- 将当前分支无关的工作状态进行暂存
```
git stash
```
- 将 HEAD 移动到需要修改的 commit 上
```
git rebase commit-id^ --interactive
```
- 找到需要修改的 commit ，将首行的 pick 改成 edit
- 进行修改
- 将改动文件添加到暂存
```
git add 
```
- 追加改动到提交
```
git commit –amend
```
- 移动 `HEAD` 回最新的 `commit`
```
git rebase –-continue
```

## 总结

- 我们发现分享 rebase 全文都是围绕 优化分支提交记录 来举例子介绍该命令,我个人觉得这也就是该命令的核心之处。
- 在学习 `rebase` 之前我日常使用的基本都是 `merge` 导致 `commit` 记录过于混乱，自己想要哪个功能节点都要找很久的提交记录,以后会慢慢尝试在项目中使用一下。毕竟谁不想要一个整洁好看的提交记录呢