#!/bin/bash

commander_dir=/opt/electriccloud/electriccommander

/data/Electric* --mode silent --installServer --unixServerUser build --unixServerGroup build --useSameServiceAccount
cp /data/mysql* $commander_dir/server/lib