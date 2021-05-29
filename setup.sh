#!/bin/bash
#初始化变量
cd "$(dirname "$0")" || exit 1
chmod +x ./shell/*
chmod +x ./remote/*
TMP_DIR=/tmp
rsync -aq ./remote $TMP_DIR
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
export CLUSTER
xcall "killall -9 java" 2>/dev/null
ENV_FILE=$($TMP_DIR/remote/config_reader.py GLOBAL EnvFile)
xcall "sed -i '/CLUSTER/d' $ENV_FILE" 2>/dev/null
xcall "echo '#CLUSTER' >> $ENV_FILE"
xcall "echo 'export CLUSTER=$CLUSTER' >> $ENV_FILE"
USERNAME=$($TMP_DIR/remote/config_reader.py GLOBAL Username)
xcall "mkdir -p /home/$USERNAME/bin"
SOURCE=$($TMP_DIR/remote/config_reader.py GLOBAL DefaultSource)

#环境准备
cp ./shell/xcall /bin
cp ./shell/xsync /bin
xsync /bin
xsync "$SOURCE"
xsync $TMP_DIR/remote

function install_packages() {
  local package=$1
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
    xcall -w "$CLUSTER" "$TMP_DIR/remote/initialize.sh $package" >/dev/null 2>&1
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
    ;;
  *) ;;
  esac
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
    ;;
  hive)
    sed -i "/^CLUSTER/s/CLUSTER=.*/CLUSTER='$CLUSTER'/" ./shell/hive_services.sh
    cp ./shell/hive_services.sh /home/$USERNAME/bin/
    ;;
  hbase)
    MASTER="$($TMP_DIR/remote/config_reader.py HBASE Master)"
    RSS="$($TMP_DIR/remote/config_reader.py HBASE RegionServer)"
    sed -i "/^MASTER/s/MASTER=.*/MASTER='$MASTER'/" ./shell/hbase.sh
    sed -i "/^RSS/s/RSS=.*/RSS='$RSS'/" ./shell/hbase.sh
    cp ./shell/hbase.sh /home/$USERNAME/bin/
    ;;
  azkaban)
    WEB="$($TMP_DIR/remote/config_reader.py AZKABAN Web)"
    EXEC="$($TMP_DIR/remote/config_reader.py AZKABAN Exec)"
    AZ_HOME="$($TMP_DIR/remote/config_reader.py AZKABAN Exec)"
    sed -i "/^AZ_WEB/s/AZ_WEB=.*/AZ_WEB='$WEB'/" ./shell/az.sh
    sed -i "/^AZ_EXEC/s/AZ_EXEC=.*/AZ_EXEC='$EXEC'/" ./shell/az.sh
    sed -i "/^AZ_HOME/s/AZ_HOME=.*/AZ_HOME='$AZ_HOME'/" ./shell/az.sh
    cp ./shell/az.sh /home/$USERNAME/bin/
    ;;
  esac
}
case $1 in
all)
  for i in java zookeeper hadoop mysql hive flume kafka spark azkaban hbase; do
    install_packages $i
  done
  ;;
java | hadoop | zookeeper | flume | kafka | hbase | spark | hive | sqoop | mysql | azkaban )
  install_packages $1
  ;;
*)
  ;;
esac
CLUSTER=$($TMP_DIR/remote/config_reader.py GLOBAL Cluster)
xsync "/home/$USERNAME/bin"
xcall "killall -9 java" 2>/dev/null
xcall "rm -rf $TMP_DIR/remote"
xcall "chown -R $USERNAME:$USERNAME /opt/* /home/$USERNAME"
