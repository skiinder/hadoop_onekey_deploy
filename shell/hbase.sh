#!/bin/bash
MASTER="hadoop102"
RSS="hadoop102,hadoop103,hadoop104"

hbase_start() {
  xcall -w "$MASTER" "hbase-daemon.sh start master"
  xcall -w "$RSS" "hbase-daemon.sh start regionserver"
}

hbase_stop() {
  xcall -w "$MASTER" "hbase-daemon.sh stop master"
  xcall -w "$RSS" "hbase-daemon.sh stop regionserver"
}

case $1 in
"start")
  hbase_start
  ;;
"stop")
  hbase_stop
  ;;
"restart")
  hbase_stop
  sleep 3
  hbase_start
  ;;
*)
  echo "usage: $(basename $0) start|stop|restart"
  ;;
esac
