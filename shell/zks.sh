#!/bin/bash
CLUSTER="hadoop102,hadoop103,hadoop104"

xcall -w "$CLUSTER" "zkServer.sh $* 2>/dev/null" | grep -v Client