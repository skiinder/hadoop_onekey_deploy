#!/bin/bash
CLUSTER="hadoop105"
IFS="," read -r -a Hosts <<<"$CLUSTER"

hive_start() {
  xcall -w "${Hosts[0]}" "nohup hive --service hiveserver2 1>/dev/null 2>&1 &"
  while ! nc -z ${Hosts[0]} 10000; do sleep 1; done
}

hive_stop() {
  xcall -w "${Hosts[0]}" "ps -ef | grep -i hiveserver2 | grep -v grep | awk '{print \$2}' | xargs -n1 kill"
}

case $1 in
start)
  hive_start
  ;;
stop)
  hive_stop
  ;;
restart)
  hive_stop
  sleep 3
  hive_start
  ;;
status)
  if nc -z ${Hosts[0]} 10000; then echo "hiveserver2正在运行"; else echo "hiveserver2未启动成功"; fi
  ;;
*) ;;
esac
