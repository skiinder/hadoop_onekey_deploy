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

## Configuration

配置文件为remote/config.ini, 每个框架的配置是一个独立的Section

[GLOBAL]

- EnvFile: 环境变量配置文件, 一般CentOS为/etc/profile.d/custom.sh, Ubuntu为/etc/environment
- Username: 所有框架运行的用户, 不能是root

- DefaultSource: 默认安装源地址, 可以是网络或本地路径, 可以被框架Archive属性覆盖

- Cluster: 集群所有节点

[所有Section共有的设置]

- Archive: 框架的安装包名称, 可以是绝对路径或相对路径
- Home: 框架安装完成以后的家目录
- Data: 框架的数据目录, 最好放在数据盘上
- Host: 框架需要安装的节点, 不论什么角色都需要

[HADOOP]

- NameNode: 安装Namenode的节点:
  如果为一个, 则是非HA模式, 需要配置SecondaryNameNode;
  如果是多个, 则配置HA模式, 需要配置JournalNode和NameService
- NameService: HA模式的NameService
- SecondaryNameNode: 非HA模式安装SecondaryNameNode的节点
- JournalNode: HA模式安装JournalNode的节点
- ResourceManager: 安装RM的节点, 如果是一个, 则为非HA模式, 如果是多个, 则为HA模式, 需要配置YarnService
- YarnService: HA模式的YarnService
- JobHistoryServer: 历史服务器节点
- Workers: 从机节点

[MYSQL]

MySQL框架不能定义安装包, 需要预先下载好5.7.16版本的RPM包, 并加好数字前缀, 列表如下:

- 01_mysql-community-common-5.7.16-1.el7.x86_64.rpm
- 02_mysql-community-libs-5.7.16-1.el7.x86_64.rpm
- 03_mysql-community-libs-compat-5.7.16-1.el7.x86_64.rpm
- 04_mysql-community-client-5.7.16-1.el7.x86_64.rpm
- 05_mysql-community-server-5.7.16-1.el7.x86_64.rpm

可配置属性如下:

- RootPassword: Root密码
- Connector: JDBC驱动的Jar包名称

[HIVE]

- MetaDB: 元数据库名称
- MySQLUser: 新建用于访问元数据库的MySQL用户名
- MySQLPassword: 新建用于访问元数据库的MySQL密码

[SPARK]

- ArchiveClean: 纯净Spark安装包, 用于Hive on spark部署
- HistoryServer: Spark历史服务器节点

[AZKABAN]

- WebArchive: Azkaban Web安装包
- ExecArchive: Azkaban Executor安装包
- DBArchive: Azkanban数据库安装包
- Web: Web端节点
- Exec: Executor节点
- DB: 数据库名称
- MySQLUser: 新建用于访问数据库的用户名
- MySQLPassword: 新建用于访问数据库的密码

[HBASE]

- Master: Master节点
- RegionServer: RegionServer节点

##Getting Started

将对应版本安装包放到/opt/software目录下, 然后以root用户身份执行以下命令

```bash
git clone https://github.com/skiinder/hadoop_onekey_deploy.git
cd hadoop_onekey_deploy
./setup.sh all
```

单独安装某一框架(以Hadoop为例)

```bash
./setup.sh hadoop
```

注: 有些框架需要依赖其他框架, 本脚本没有判断, 需要使用者自行注意