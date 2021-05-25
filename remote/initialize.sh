#!/bin/bash
#初始化变量
TMP_DIR=/tmp
USERNAME=$($TMP_DIR/remote/config_reader.py GLOBAL Username)
SOURCE=$($TMP_DIR/remote/config_reader.py GLOBAL DefaultSource)

package=$1
case $package in
hadoop)
  IFS="," read -r -a NNs <<<"$($TMP_DIR/remote/config_reader.py HADOOP NameNode)"
  if [ "${#NNs[@]}" -eq 1 ]; then
    if [ "$NN" = "$HOSTNAME" ]; then
      su "$USERNAME" -c 'hdfs namenode -format'
    fi
  else
    if [ "${NNs[0]}" = "$HOSTNAME" ]; then
      ZK=$($TMP_DIR/remote/config_reader.py ZOOKEEPER Host)
      xcall -w "$ZK" 'zkServer.sh start'
      JN=$($TMP_DIR/remote/config_reader.py HADOOP JournalNode)
      su "$USERNAME" -c "hdfs --workers --hostnames '$JN' --daemon start journalnode"
      su "$USERNAME" -c 'hdfs zkfc -formatZK -force'
      for jn in ${JN//,/ }; do
        while ! nc -z "$jn" 8485; do sleep 1; done
      done
      su "$USERNAME" -c 'hdfs namenode -format'
      su "$USERNAME" -c 'hdfs --daemon start namenode'
    fi
    while ! nc -z "${NNs[0]}" 8020; do sleep 1; done
    for ((i = 1; i < ${#NNs[@]}; i++)); do
      if [ "${NNs[i]}" = "$HOSTNAME" ]; then
        su "$USERNAME" -c 'hdfs namenode -bootstrapStandby'
      fi
    done
    sleep 5
    su "$USERNAME" -c 'hdfs --daemon stop namenode'
    su "$USERNAME" -c 'hdfs --daemon stop journalnode'
  fi
  ;;
mysql)
  MySQL_PASS=$($TMP_DIR/remote/config_reader.py MYSQL RootPassword)
  service mysql stop 2>/dev/null
  service mysqld stop 2>/dev/null
  rpm -qa | grep -i -E mysql\|mariadb | xargs -n1 rpm -e --nodeps
  rm -rf /var/lib/mysql
  rm -rf /usr/lib64/mysql
  rm -rf /etc/my.cnf
  rm -rf /usr/my.cnf
  rm -rf /var/log/mysqld.log
  rpm -Uvh $SOURCE/01_mysql-community-common-5.7.16-1.el7.x86_64.rpm 1>/dev/null 2>&1
  rpm -Uvh $SOURCE/02_mysql-community-libs-5.7.16-1.el7.x86_64.rpm 1>/dev/null 2>&1
  rpm -Uvh $SOURCE/03_mysql-community-libs-compat-5.7.16-1.el7.x86_64.rpm 1>/dev/null 2>&1
  rpm -Uvh $SOURCE/04_mysql-community-client-5.7.16-1.el7.x86_64.rpm 1>/dev/null 2>&1
  rpm -Uvh $SOURCE/05_mysql-community-server-5.7.16-1.el7.x86_64.rpm 1>/dev/null 2>&1
  systemctl start mysqld
  PASSWORD=$(grep password /var/log/mysqld.log | cut -d " " -f 11)
  mysql -uroot -p"$PASSWORD" --connect-expired-password --execute="
set password=password(\"Qs23=zs32\");
set global validate_password_length=4;
set global validate_password_policy=0;
set password=password(\"$MySQL_PASS\");
update mysql.user set host=\"%\" where user=\"root\";
flush privileges;" 2>/dev/null
  ;;
hive)
  IFS="," read -r -a HOSTS <<<"$($TMP_DIR/remote/config_reader.py HIVE Host)"
  if [ "${HOSTS[0]}" = "$HOSTNAME" ]; then
    MySQL_Host=$($TMP_DIR/remote/config_reader.py MYSQL Host)
    MySQL_PASS=$($TMP_DIR/remote/config_reader.py MYSQL RootPassword)
    HiveUser=$($TMP_DIR/remote/config_reader.py HIVE MySQLUser)
    HivePass=$($TMP_DIR/remote/config_reader.py HIVE MySQLPassword)
    MetaDB=$($TMP_DIR/remote/config_reader.py HIVE MetaDB)
    ssh "$MySQL_Host" "mysql -uroot -p'$MySQL_PASS' --execute=\"
drop database if exists $MetaDB;
create database $MetaDB;
CREATE USER if not exists '$HiveUser'@'%' IDENTIFIED BY '$HivePass';
GRANT ALL ON $MetaDB.* to '$HiveUser'@'%' WITH GRANT OPTION;\"" 1>/dev/null 2>&1
    schematool -initSchema -dbType mysql -verbose
  fi
  ;;
spark)
  IFS="," read -r -a HOSTS <<<"$($TMP_DIR/remote/config_reader.py HIVE Host)"
  if [ "${HOSTS[0]}" = "$HOSTNAME" ]; then
    ArchiveClean=$($TMP_DIR/remote/config_reader.py SPARK ArchiveClean)
    if [[ ! "$ArchiveClean" =~ ^http ]] || [[ ! "$ArchiveClean" =~ ^/ ]]; then
      ArchiveClean=$SOURCE/$ArchiveClean
    fi
    $TMP_DIR/remote/extract_tar.py "$ArchiveClean" $TMP_DIR/spark
    su - "$USERNAME" -c "start-dfs.sh"
    su - "$USERNAME" -c "hdfs dfsadmin -safemode wait"
    su - "$USERNAME" -c "hadoop fs -mkdir -p /spark/history"
    su - "$USERNAME" -c "hadoop fs -mkdir -p /spark/jars"
    su - "$USERNAME" -c "hadoop fs -put $TMP_DIR/spark/jars/* /spark/jars/ >/dev/null 2>&1"
    su - "$USERNAME" -c "stop-dfs.sh"
    rm -rf $TMP_DIR/spark
  fi
  ;;
*) ;;

esac
