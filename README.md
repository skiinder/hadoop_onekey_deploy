# Hadoop生态一键部署脚本
## Prerequisite

- 最小化安装Centos 7.x
- 关闭集群防火墙
- 新建一个一般用户
- 为该用户配置超级管理员权限
- 配置所有节点的ip和hostname映射
- 配置所有节点相互免密登录, root用户和一般用户都需要
- 其他依赖如下

```bash
sudo yum install -y epel-release
sudo yum install -y psmisc nc net-tools rsync vim lrzsz ntp libzstd openssl-static libaio pv pdsh python3-devel
sudo pip3 install requests
```


