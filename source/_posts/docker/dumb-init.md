---
title:  Docker 处理信号
date: 2023-02-03 15:18:17
tags:
categories: OpenStack
---

# 如何处理容器的信号

## 关于容器与信号的关系
- 当你在执行 `Docker` 容器时，主要执行程序(`Process`)的 PID 将会是 `1`，只要这个程序停止，容器就会跟著停止

- 由于容器中一直没有像 `systemd` 或 `sysvinit` 这类的初始化系统(`init system`)，少了初始化系统来管理程序，会导致当程序不稳定的时候，无法进一步有效的处理程序的状态，或是无法有效的控制 `Signal` 处理机制

- 我们以 `docker stop` 为例，这个命令实质上是对容器中的 PID `1` 发出一个 `SIGTERM` 信号，如果程序本身并没有处理 `Signal` 的机制，就会直接忽略这类信号，这就会导致 `docker stop` 等了 `10` 秒之后还不结束，然后 `Docker Engine` 又会对 PID `1` 送出另一个 `SIGKILL` 讯号，试图强迫杀死这个程序，这才会让容器彻底停下来

## 没有正确处理 Signal 的情况
我们用一个最简单的例子来说明：

1、执行简单的 sleep 命令
```
docker run -it --rm --name=test ubuntu /bin/sh -c "sleep 100000"
```
2、然后我们试著停止这个容器
```
docker stop test
```
3、此时你会发现要等 `10` 秒，容器才会结束！

4、会发生无法立刻停止的状况，其实是 `/bin/sh` 预设并不会处理(`handle`)信号，所以他会把所有不认得的信号忽略，直到系统把他沙掉为止。

## 正确处理 Signal 的情况
1、建立一个空文件夹，并且建立一个 `test.sh` 文件

脚本中使用 `trap 'exit 0' SIGTERM` 来处理 `SIGTERM` 讯号，接收到讯号就直接以状态码 `0` 正常的退出：
```
#!/usr/bin/env sh
trap 'exit 0' SIGTERM
while true; do :; done
```

2、撰写一个 `Dockerfile` 来构建一个名为 `test:latest` 的 `Image`
```
FROM alpine
COPY test.sh /
ENTRYPOINT [ "/test/sh" ]
```

3、构建容器映像
```
docker build -t test:latest .
```
4、执行容器
```
docker run -it --rm --name=test test:latest
```
5、然后我们试著停止这个容器
```
docker stop test
```
此时你会发现，容器收到讯号之后就会立刻结束！


## 使用 dumb-init 控制所有启动的程序
- 有时候我们会通过 Shell Script 启动一些其他的程式，有些甚至是背景服务。
- 但是，当 Shell 接收到 SIGTERM 讯号的时候，并不会转传收到的讯号给子程序(Sub-process)，所以就算你的 Shell Script 收到信号，其他子程序是不会收到信号的，所以程序并不会停止

- 这个状况有个非常简单的解决方式，就是把 `#!/usr/bin/env sh` 修改成 `#!/usr/bin/dumb-init /bin/sh` 即可！

```
#!/usr/bin/dumb-init /bin/sh
my-web-server &  # launch a process in the background
my-other-server  # launch another process in the foreground
```

## 使用 dumb-init 控制信号覆写 (Signal rewriting)
- 有些特定的服务并不会接收 `SIGTERM` 讯号。例如 `nginx` 预设若要执行优雅的结束，必须对他送出 `SIGQUIT` 讯号。而 `Apache HTTP Server` 则要送出 `SIGWINCH` 讯号，才会优雅的结束。

- 由于 `docker stop` 预设会送出 `SIGTERM` 服务为主，所以如果你打算自己封装 `nginx` 容器的话，送出正确的讯号就十分重要。

- 如果你直接使用 `nginx` 容器映像，其实不用特别处理，因为你可以看 `nginx` 的 `Dockerfile` 已经设定了 `STOPSIGNAL SIGQUIT` 指令，所以当有人对这个容器送出 `docker stop` 命令时，本来就会转送 `SIGQUIT` 讯号过去，不需要靠 `dumb-init` 的帮助。

- 当然，如果你有特别的需求，才需要把 `SIGTERM (15)` 转送成 `SIGQUIT (3)` 这样写：
```
ENTRYPOINT [ "/usr/bin/dumb-init", "--rewrite", "15:3", "--" ]
CMD [ "curl", "http://http.speed.hinet.net/test_9216m.zip", "-o", "/dev/null" ]
```
- 完整的讯号名称与编号可以透过 Linux 下的 kill -l 命令查询。

- 以下是 `dumb-init` 的参数选项说明：
```
dumb-init v1.2.2
Usage: dumb-init [option] command [[arg] ...]

dumb-init is a simple process supervisor that forwards signals to children.
It is designed to run as PID1 in minimal container environments.

Optional arguments:
   -c, --single-child   Run in single-child mode.
                        In this mode, signals are only proxied to the
                        direct child and not any of its descendants.
   -r, --rewrite s:r    Rewrite received signal s to new signal r before proxying.
                        To ignore (not proxy) a signal, rewrite it to 0.
                        This option can be specified multiple times.
   -v, --verbose        Print debugging information to stderr.
   -h, --help           Print this help message and exit.
   -V, --version        Print the current version and exit.

Full help is available online at https://github.com/Yelp/dumb-init
```

## 使用 tini 初始化系统

- `tini` 是一套更简单的 `init` 系统，专门用来执行一个子程序(`spawn a single child`)，并等待子程序结束，即便子程序已经变成僵尸程序(`zombie process`)也能捕捉到，同时也能转送 `Signal` 给子程序。

- 如果你使用 `Docker` 来跑容器，可以非常简便的在 `docker run` 的时候用 `--init` 参数，就会自动注入 `tini` 程式 (`/sbin/docker-init`) 到容器中，并且自动取代 `ENTRYPOINT` 设定，让原本的程式直接跑在 `tini` 程序底下！

- 注意：Docker 1.13 以后的版本才开始支持 `--init` 参数，并内建 `tini` 在内。

1、不用 `--init` 的情况

直接启动 `sleep` 跑 100 秒
```
docker run -it --rm --name=test alpine sleep 100
```
使用 `ps -ef` 可以得知 `sleep 100` 进程会直接跑在 PID `1` 底下
```
docker exec -it test ps -ef
```
```
PID   USER     TIME  COMMAND
    1 root      0:00 sleep 100
    8 root      0:00 ps -ef
```
停止容器需要 10 秒才能完成
```
docker stop test
```

2、使用 `--init` 的情况

使用 `--init` 启动 `sleep` 程式跑 100 秒
```
docker run -it --rm --name=test --init alpine sleep 100
```
使用 `ps -ef` 可以得知 `sleep 100` 进程会跑在 `/sbin/docker-init --` 命令下

```
docker exec -it test ps -ef
```
```
PID   USER     TIME  COMMAND
    1 root      0:00 /sbin/docker-init -- sleep 100
    8 root      0:00 sleep 100
    9 root      0:00 ps -ef
```
停止容器只需要 1 秒内就可以完成
```
docker stop test
```