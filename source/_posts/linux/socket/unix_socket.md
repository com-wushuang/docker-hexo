---
title: unix domain socket 以及其在 QGA 中的应用
date: 2023-12-14 12:23:49
tags:
categories: OpenStack
--- 

### 概述
Linux下进程通讯方式有很多,比较典型的有套接字,平时比较常用的套接字是基于TCP/IP协议的,适用于两台不同主机上两个进程间通信, 通信之前需要指定IP地址. 但是如果同一台主机上两个进程间通信用套接字,还需要指定ip地址,有点过于繁琐. 这个时候就需要用到UNIX Domain Socket, 简称UDS,  UDS的优势:
- UDS传输不需要经过网络协议栈,不需要打包拆包等操作,只是数据的拷贝过程
- UDS分为SOCK_STREAM(流套接字)和SOCK_DGRAM(数据包套接字),由于是在本机通过内核通信,不会丢包也不会出现发送包的次序和接收包的次序不一致的问题