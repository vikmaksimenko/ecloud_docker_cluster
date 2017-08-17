#!/bin/bash

# Wait for the Commander server on the local host to reach the
## "running" state.

logfile="/opt/electriccloud/electriccommander/logs/commander-$(hostname).log"

while true ; do
    test -e $logfile && grep "commanderServer is running" $logfile
    if [ $? == 0 ] ; then
        break
    else
        sleep 10
    fi
done
