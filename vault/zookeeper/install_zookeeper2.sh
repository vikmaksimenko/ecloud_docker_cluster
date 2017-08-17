#!/bin/bash

ZK_VERSION=${1:-zookeeper-3.4.9}

wget http://apache.cp.if.ua/zookeeper/$ZK_VERSION/$ZK_VERSION.tar.gz
tar -zxvf $ZK_VERSION.tar.gz

