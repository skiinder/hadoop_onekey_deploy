#!/bin/bash
#初始化变量
chmod +x ./shell/*
chmod +x ./remote/*
TMP_DIR=/tmp
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
export CLUSTER
xcall "killall -9 java"
xcall rm -rf /opt/module/* /opt/data/*
rsync -av ./remote $TMP_DIR
ENV_FILE=$($TMP_DIR/remote/config_reader.py GLOBAL EnvFile)
xcall "sed -i '/CLUSTER/d' $ENV_FILE"
xcall "echo '#CLUSTER' >> $ENV_FILE"
xcall "echo 'export CLUSTER=$CLUSTER' >> $ENV_FILE"
USERNAME=$($TMP_DIR/remote/config_reader.py GLOBAL Username)
SOURCE=$($TMP_DIR/remote/config_reader.py GLOBAL DefaultSource)

#环境准备
cp ./shell/xcall /bin
cp ./shell/xsync /bin
rsync -av ./remote "$TMP_DIR"
xsync /bin
xsync "$SOURCE"
xsync $TMP_DIR/remote

function install_packages() {
  local package=$1
  case $package in
  java | hadoop | zookeeper | flume | kafka | hbase | spark | hive)
    CLUSTER=$($TMP_DIR/remote/config_reader.py $(echo $package | tr 'a-z' 'A-Z') Host)
    echo "解压$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/extract_tar.py $package"
    echo "设置$1家目录"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/set_home.py $package"
    echo "配置$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/configuration.py $package"
    echo "初始化$1"
    xcall -w "$CLUSTER" "$TMP_DIR/remote/initialize.sh $package"
    ;;
  mysql)
    MySQL_Host=$($TMP_DIR/remote/config_reader.py MYSQL Host)
    ssh "$MySQL_Host" "$TMP_DIR/remote/initialize.sh $package"
    ;;
  *) ;;
  esac
}

for i in java zookeeper hadoop mysql hive flume kafka spark; do
  echo "正在处理$i"
  install_packages $i
done
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
xcall "killall -9 java"
xcall "chown -R $USERNAME:$USERNAME /opt/*"
