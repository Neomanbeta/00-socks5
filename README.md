# serv00/兼容ct8的无交互部署socks5和tuic脚本

### 2024.8.30：经过几天测试，这个方法仍然无法让所有的优选节点的SOCKS5反代生效，只能部分节点有效，所以在能找到完美解决的办法之前不再更新（或者等小火箭，loon等软件更新支持）。

### 如果你需要在iOS下使用SOCKS5做反代的edgetunnel和epeius项目，完全没有问题的客户端是Karing https://karing.app  推荐使用这个客户端，免费而且无广告。

### 前言
**这个脚本要实现的目的**：在serv00上创建socks5给cmliu的edgetunnel和 epeius项目做SOCKS5变量用的反代，由于serv00没有流量限制，而且线路可以解锁GPT桌面端和客户端，所以很合适。

**为什么要重复造这个轮子**：cmliu已经有了[socks5-for-serv00](https://github.com/cmliu/socks5-for-serv00 "socks5-for-serv00")项目来做这个事情，为什么我还要再弄一个。原因主要是为了解决iOS某些客户端，比如很多人用的小火箭，loon，等等，无法使用用了socks5做反代的edgetunnel和 epeius项目，具体情况表现为ip.sb这种CF CDN网站打不开。用这个项目创建的socks5就可以在这些有问题的客户端上正常使用了。

**为什么会有个TUIC**：serv00一共给你3个端口，剩下一个留着也是浪费，就带上了老王的单协议tuic做节点用。

**有什么限制**：serv00到现在有s1到s10这10个服务器了。其中有几个是没有UDP支持的，这个脚本安装了也不会好使，所以使用之前自行判别自己的serv00服务器是否支持UDP。

### 致谢
https://github.com/cmliu cmliu的edgetunnel和epeius

https://github.com/eooce 老王的serv00无交互脚本作为模板省去了很多重写和测试的时间

https://github.com/0990/socks5 0990的socks5服务端源码来实现必要的功能

### 使用说明
- serv00必须允许运行自定义程序，并且添加3个随机端口，一个TCP，两个UDP
- 必填变量：`PORT=TUIC使用的UDP端口` `STCP=SOCKS5使用的TCP端口` `SUDP=SOCKS5使用的UDP端口`
- 可选变量：`UUID SOCKSU SOCKSP NEZHA_SERVER NEZHA_PORT NEZHA_KEY`
- `SOCKSU`和`SOCKSP`是socks5代理的用户名和密码变量，如果不使用那么会使用脚本内置的用户名`oneforall`和密码`allforone`，注意设置用户名和密码变量的时候，不要包含@和:字符，否则会引起解析失败或者传送用户名密码失败。

```
PORT=TUIC使用的UDP端口 STCP=SOCKS5使用的TCP端口 SUDP=SOCKS5使用的UDP端口 bash <(curl -Ls https://github.com/Neomanbeta/00-socks5/raw/main/00_ss5.sh)
```

### TODO
保活：自行发挥吧，我的方法不适合所有人。

### 附言
## 不要把socks5作为节点使用，不要添加到你的代理软件里，不要直连！
