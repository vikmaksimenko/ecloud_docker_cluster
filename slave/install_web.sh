#!/bin/bash

haproxy_ip="$1"
hostname=$(hostname)
commander_dir="/opt/electriccloud/electriccommander"
ectool="$commander_dir/bin/ectool"

/data/Electric* --mode silent --installWeb --unixServerUser build --unixServerGroup build --unixAgentGroup build --unixAgentUser build --remoteServer $haproxy_ip
/etc/init.d/commanderApache restart

$commander_dir/bin/ecconfigure --webTargetHostName $haproxy_ip
$ectool --server $haproxy_ip login admin changeme
$ectool --server $haproxy_ip deleteResource $hostname
$ectool --server $haproxy_ip createResource $hostname --hostName $hostname --port 7800 --resourcePools local,default