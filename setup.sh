#!/bin/bash
#检查是否为root用户
if [ ! "$(whoami)" = "root" ]; then
  echo "请用root用户执行该脚本"
  exit;
fi

#初始化变量
cd "$(dirname "$0")" || exit 1
chmod +x ./shell/*
chmod +x ./remote/*

# 准备部署过程中需要用到的分布式操作脚本
cp ./shell/xcall /bin
cp ./shell/xsync /bin

# 将Remote目录拷贝到临时目录, 并分发, 以供分布式执行
TMP_DIR=/tmp
rsync -aq ./remote $TMP_DIR
# 全局声明CLUSTER变量以供子脚本调用
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
export CLUSTER
xsync /bin
xsync $TMP_DIR/remote

# 将CLUSTER变量添加到环境变量，供集群部署好之后使用
ENV_FILE=$($TMP_DIR/remote/config_reader.py GLOBAL EnvFile)
xcall "sed -i '/CLUSTER/d' $ENV_FILE" 2>/dev/null
xcall "echo '#CLUSTER' >> $ENV_FILE"
xcall "echo 'export CLUSTER=$CLUSTER' >> $ENV_FILE"

# 关闭所有之前正在运行的Java程序
xcall "killall -9 java" 2>/dev/null

# 新建用户的脚本目录
USERNAME=$($TMP_DIR/remote/config_reader.py GLOBAL Username)
xcall "mkdir -p /home/$USERNAME/bin"

SOURCE=$($TMP_DIR/remote/config_reader.py GLOBAL DefaultSource)
xsync "$SOURCE"

function install_packages() {
  local package=$1

  # 执行框架安装过程
  case $package in
  java | hadoop | zookeeper | flume | kafka | hbase | spark | hive | sqoop)
    CLUSTER=$($TMP_DIR/remote/config_reader.py "$(echo $package | tr 'a-z' 'A-Z')" Host)
    echo "将""$package""安装到""$CLUSTER"
    Data_dir=$($TMP_DIR/remote/config_reader.py "$(echo $package | tr 'a-z' 'A-Z')" Data)
    Home_dir=$($TMP_DIR/remote/config_reader.py "$(echo $package | tr 'a-z' 'A-Z')" Home)
    xcall -w "$CLUSTER" "rm -rf $Data_dir $Home_dir"
    echo "解压$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/extract_tar.py $package" >/dev/null 2>&1
    echo "设置$1家目录"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/set_home.py $package" >/dev/null 2>&1
    echo "配置$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/configuration.py $package" >/dev/null 2>&1
    echo "初始化$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/initialize.sh $package"
    ;;
  mysql)
    MySQL_Host=$($TMP_DIR/remote/config_reader.py MYSQL Host)
    echo "将""$package""安装到""$MySQL_Host"
    ssh "$MySQL_Host" "$TMP_DIR/remote/initialize.sh $package" >/dev/null 2>&1
    ;;
  azkaban)
    AZ_Host=$($TMP_DIR/remote/config_reader.py AZKABAN Host)
    echo "将""$package""安装到""$AZ_Host"
    xcall -w "$AZ_Host" "$TMP_DIR/remote/initialize.sh $package" >/dev/null 2>&1
    ;;
  shucang)
    SC_HOST=$($TMP_DIR/remote/config_reader.py SHUCANG Host)
    echo "将$package""安装到$SC_HOST"
    xcall -w "$SC_HOST" "$TMP_DIR/remote/initialize.sh $package"
    ;;
  *) ;;
  esac

  # 框架安装完成后需要执行的初始化操作, 主要是生成集群操作脚本
  case $package in
  java)
    sed -i "/^CLUSTER/s/CLUSTER=.*/CLUSTER='$CLUSTER'/" ./shell/jpsall
    cp ./shell/jpsall /bin/
    ;;
  kafka)
    sed -i "/^CLUSTER/s/CLUSTER=.*/CLUSTER='$CLUSTER'/" ./shell/kafka.sh
    cp ./shell/kafka.sh /home/$USERNAME/bin/
    ;;
  zookeeper)
    sed -i "/^CLUSTER/s/CLUSTER=.*/CLUSTER='$CLUSTER'/" ./shell/zks.sh
    cp ./shell/zks.sh /home/$USERNAME/bin/
    /home/$USERNAME/bin/zks.sh start
    ;;
  hadoop)
    su - "$USERNAME" -c "start-dfs.sh"
    su - "$USERNAME" -c "start-yarn.sh"
    ;;
  hive)
    sed -i "/^CLUSTER/s/CLUSTER=.*/CLUSTER='$CLUSTER'/" ./shell/hive_services.sh
    cp ./shell/hive_services.sh /home/$USERNAME/bin/
    ;;
  hbase)
    MASTER="$($TMP_DIR/remote/config_reader.py HBASE Master)"
    RSS="$($TMP_DIR/remote/config_reader.py HBASE RegionServer)"
    sed -i "/^MASTER/s/MASTER=.*/MASTER='$MASTER'/" ./shell/hbase.sh
    sed  -i "/^RSS/s/RSS=.*/RSS='$RSS'/" ./shell/hbase.sh
    cp ./shell/hbase.sh /home/$USERNAME/bin/
    ;;
  azkaban)
    WEB="$($TMP_DIR/remote/config_reader.py AZKABAN Web)"
    EXEC="$($TMP_DIR/remote/config_reader.py AZKABAN Exec)"
    AZ_HOME="$($TMP_DIR/remote/config_reader.py AZKABAN Home)"
    sed -i "/^AZ_WEB/s/AZ_WEB=.*/AZ_WEB='$WEB'/" ./shell/az.sh
    sed -i "/^AZ_EXEC/s/AZ_EXEC=.*/AZ_EXEC='$EXEC'/" ./shell/az.sh
    sed -i "/^AZ_HOME/s/AZ_HOME=.*/AZ_HOME='${AZ_HOME//\//\\/}'/" ./shell/az.sh
    cp ./shell/az.sh /home/$USERNAME/bin/
    ;;
  esac
}

#
case $1 in
all)
  for i in java zookeeper hadoop mysql hive sqoop flume kafka spark azkaban hbase shucang; do
    install_packages $i
  done
  ;;
java | hadoop | zookeeper | flume | kafka | hbase | spark | hive | sqoop | mysql | azkaban | shucang)
  install_packages $1
  ;;
*)
  ;;
esac

#停止安装过程中开启的框架
"/home/${USERNAME}/bin/zks.sh" stop
su - "$USERNAME" -c "stop-dfs.sh"
su - "$USERNAME" -c "stop-yarn.sh"

# 同步生成的脚本,执行清理工作
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
xsync "/home/$USERNAME/bin"
xsync "/bin"
xcall "rm -rf $TMP_DIR/remote"
xcall "chown -R $USERNAME:$USERNAME /opt/* /home/$USERNAME"
