# 我的vps都做了什么

## 梯子
### 工具
- 系统:ubuntu 18.04
- 服务器:caddy
- 代理协议:trojan-go
- BBR加速
### BBR加速
- 修改系统变量：
```
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
```
- 保存生效:
```
sysctl -p
```
- 执行:
```
sysctl net.ipv4.tcp_available_congestion_control
```
- 执行结果：
```
sysctl net.ipv4.tcp_available_congestion_control
net.ipv4.tcp_available_congestion_control = bbr cubic reno
```
- 查看是否生效：
```
lsmod | grep bbr 
```
### 代理协议
采用源码编译安装方式，安装成systemd service的形式
- clone
```
git clone https://github.com/p4gefau1t/trojan-go.git -b v0.10.6
```
- make install。Makefile 相关细节如下
```
install: $(BUILD_DIR)/$(NAME) geoip.dat geoip-only-cn-private.dat geosite.dat
	mkdir -p /etc/$(NAME)
	mkdir -p /usr/share/$(NAME)
	cp example/*.json /etc/$(NAME)
	cp $(BUILD_DIR)/$(NAME) /usr/bin/$(NAME)
	cp example/$(NAME).service /usr/lib/systemd/system/
	cp example/$(NAME)@.service /usr/lib/systemd/system/
	systemctl daemon-reload
	cp geosite.dat /usr/share/$(NAME)/geosite.dat
	cp geoip.dat /usr/share/$(NAME)/geoip.dat
	cp geoip-only-cn-private.dat /usr/share/$(NAME)/geoip-only-cn-private.dat
	ln -fs /usr/share/$(NAME)/geoip.dat /usr/bin/
	ln -fs /usr/share/$(NAME)/geoip-only-cn-private.dat /usr/bin/
	ln -fs /usr/share/$(NAME)/geosite.dat /usr/bin/
```
- 安装成 systemd service，从上面的Makefile细节我们可以看到文件路径
```
[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/trojan-go -config /etc/trojan-go/config.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.targe
```
- 我们看到配置文件的路径在 /etc/trojan-go/config.json
```
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,           # trojan-go监听端口
    "remote_addr": "127.0.0.1",
    "remote_port": 80,           # caddy服务
    "password": [
        "*****"
    ],
    "ssl": {
        "cert": "/etc/trojan-go/server.crt",
        "key": "/etc/trojan-go/server.key"
    }
}
```
- 配置原理参考：https://p4gefau1t.github.io/trojan-go/basic/trojan/
### Caddy
- 官网安装，非常简单
- 配置文件 Caddyfile
```
:80

respond "Hello, world!"
```
- caddy run
- 看到 80 端口就是个简单的 hell world，后面会改成个人博客。

## blog
- blog 用docker的方式运行，然后反向代理到caddy的80端口
- 因为80对口需要留给trojan用，用来伪装代理
- caddy 配置反向代理非常的简单
```
:80

reverse_proxy 127.0.0.1:8080
```

## bbr plus 加速
- 测速
```
docker pull adolfintel/speedtest
docker run -d -p 80:80 adolfintel/speedtest
```
- 选择合适的加速模块，本机是 ubuntu 18.04 。只支持 bbr plus加速，但是也好过 bbr 加速。
```
wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```