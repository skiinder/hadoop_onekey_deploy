#!/bin/bash
CLUSTER="hadoop102,hadoop103,hadoop104"

kafka_start() {
    xcall -w "$CLUSTER" "kafka-server-start.sh -daemon \$KAFKA_HOME/config/server.properties"
}

kafka_stop() {
    xcall -w "$CLUSTER" "kafka-server-stop.sh"
}

kafka_status() {
    xcall -w "$CLUSTER" "if nc -z localhost 9092; then echo '状态正常'; else echo '状态异常'; fi"
}

case $1 in
start)
  kafka_start
  ;;
stop)
  kafka_stop
  ;;
restart)
  kafka_stop
  sleep 5
  kafka_start
  ;;
status)
  kafka_status
  ;;
*) ;;
esac
