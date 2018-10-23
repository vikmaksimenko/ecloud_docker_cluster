#!/bin/bash

haproxy_ip="$1"
hostname=$(hostname)
commander_dir="/opt/electriccloud/electriccommander"
ectool="$commander_dir/bin/ectool"

sudo /data/Electric* \
--mode silent \
--installAgent \
--unixAgentGroup build \
--unixAgentUser build \
--remoteServer $haproxy_ip \
--remoteServerUser admin \
--remoteServerPassword changeme \
--agentPluginsDirectory "/plugins" 

$ectool --server $haproxy_ip login admin changeme
$ectool deleteResource $hostname
$ectool createResource $hostname --hostName $hostname --port 7800 --resourcePools local,default
