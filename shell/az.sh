#!/bin/bash
AZ_WEB="hadoop102"
AZ_EXEC="hadoop102,hadoop103,hadoop104"
AZ_HOME="/opt/module/azkaban"

az_start() {
  xcall -w "$AZ_EXEC" "cd $AZ_HOME/exec; bin/start-exec.sh; sleep 3; curl -sG "localhost:12321/executor?action=activate"&&echo"
  xcall -w "$AZ_WEB" "cd $AZ_HOME/web; bin/start-web.sh"
}

az_stop() {
  xcall -w "$AZ_EXEC" "cd $AZ_HOME/exec;bin/shutdown-exec.sh"
  xcall -w "$AZ_WEB" "cd $AZ_HOME/web; bin/shutdown-web.sh"
}

case $1 in
"start")
  az_start
  ;;
"stop")
  az_stop
  ;;
"restart")
  az_stop
  sleep 3
  az_start
  ;;
*)
  echo "usage: $(basename $0) start|stop|restart"
  ;;
esac
