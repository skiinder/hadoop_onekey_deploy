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
  sed -i '/max_allowed_packet/d' /etc/my.cnf
  sed -i '/\[mysqld\]/amax_allowed_packet=1024M' /etc/my.cnf
  systemctl restart mysqld
  ;;
hive)
  IFS="," read -r -a HOSTS <<<"$($TMP_DIR/remote/config_reader.py HIVE Host)"
  if [ "${HOSTS[0]}" = "$HOSTNAME" ]; then
    MySQL_Host="$($TMP_DIR/remote/config_reader.py MYSQL Host)"
    MySQL_PASS="$($TMP_DIR/remote/config_reader.py MYSQL RootPassword)"
    HiveUser="$($TMP_DIR/remote/config_reader.py HIVE MySQLUser)"
    HivePass="$($TMP_DIR/remote/config_reader.py HIVE MySQLPassword)"
    MetaDB="$($TMP_DIR/remote/config_reader.py HIVE MetaDB)"
    ssh "$MySQL_Host" "mysql -uroot -p'$MySQL_PASS'" <<EOF 1>/dev/null 2>&1
set global validate_password_length=4;
set global validate_password_policy=0;
drop database if exists $MetaDB;
create database $MetaDB;
CREATE USER if not exists '$HiveUser'@'%' IDENTIFIED BY '$HivePass';
GRANT ALL ON $MetaDB.* to '$HiveUser'@'%' WITH GRANT OPTION;
EOF
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
azkaban)
  AZ_HOME="$($TMP_DIR/remote/config_reader.py AZKABAN Home)"
  rm -rf "$AZ_HOME"
  mkdir -p "$AZ_HOME"
  WEB="$($TMP_DIR/remote/config_reader.py AZKABAN Web)"
  IFS="," read -r -a EXECs <<<"$($TMP_DIR/remote/config_reader.py AZKABAN Exec)"
  if [ "$WEB" = "$HOSTNAME" ]; then
    MySQL_Host="$($TMP_DIR/remote/config_reader.py MYSQL Host)"
    MySQL_PASS="$($TMP_DIR/remote/config_reader.py MYSQL RootPassword)"
    Az_User="$($TMP_DIR/remote/config_reader.py AZKABAN MySQLUser)"
    Az_Pass="$($TMP_DIR/remote/config_reader.py AZKABAN MySQLPassword)"
    Az_DB="$($TMP_DIR/remote/config_reader.py AZKABAN DB)"
    WEB_ARCHIVE=$($TMP_DIR/remote/config_reader.py AZKABAN WebArchive)
    if [[ ! "$WEB_ARCHIVE" =~ ^http ]] || [[ ! "$WEB_ARCHIVE" =~ ^/ ]]; then
      WEB_ARCHIVE=$SOURCE/$WEB_ARCHIVE
    fi
    DB_ARCHIVE=$($TMP_DIR/remote/config_reader.py AZKABAN DBArchive)
    if [[ ! "$DB_ARCHIVE" =~ ^http ]] || [[ ! "$DB_ARCHIVE" =~ ^/ ]]; then
      DB_ARCHIVE=$SOURCE/$DB_ARCHIVE
    fi

    $TMP_DIR/remote/extract_tar.py "$WEB_ARCHIVE" "$AZ_HOME/web"
    $TMP_DIR/remote/extract_tar.py "$DB_ARCHIVE" "$AZ_HOME/db"

    ssh "$MySQL_Host" "mysql -uroot -p'$MySQL_PASS'" <<EOF 1>/dev/null 2>&1
set global validate_password_length=4;
set global validate_password_policy=0;
drop database if exists $Az_DB;
create database $Az_DB;
CREATE USER if not exists '$Az_User'@'%' IDENTIFIED BY '$Az_Pass';
GRANT ALL ON $Az_DB.* to '$Az_User'@'%' WITH GRANT OPTION;
EOF
    ssh "$MySQL_Host" "mysql -u$Az_User -p'$Az_Pass' -D'$Az_DB'" <"$AZ_HOME/db/create-all-sql-3.84.4.sql" 1>/dev/null 2>&1
    $TMP_DIR/remote/configuration.py az-web
    sed -i '/<azkaban-users>/a<user password="atguigu" roles="metrics,admin" username="atguigu"\/>' $AZ_HOME/web/conf/azkaban-users.xml
  fi
  for EXEC in "${EXECs[@]}"; do
    if [ "$EXEC" = "$HOSTNAME" ]; then
      EXEC_ARCHIVE=$($TMP_DIR/remote/config_reader.py AZKABAN ExecArchive)
      if [[ ! "$EXEC_ARCHIVE" =~ ^http ]] || [[ ! "$EXEC_ARCHIVE" =~ ^/ ]]; then
        EXEC_ARCHIVE=$SOURCE/$EXEC_ARCHIVE
      fi
      $TMP_DIR/remote/extract_tar.py "$EXEC_ARCHIVE" "$AZ_HOME/exec"
      $TMP_DIR/remote/configuration.py az-exec
    fi
  done
  ;;
*) ;;

esac
