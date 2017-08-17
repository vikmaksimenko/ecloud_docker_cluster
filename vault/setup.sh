#!/bin/bash
#
# Setup cluster based on Docker containers
# 
# Parameters:
#
# -s, --slaveNumber	- number of cluster slaves to run 
# -d, --dbType		- DBMS name. Can be [MYSQL]
#
# Usage:
#
# 	./setup.sh --slaveNumber 3 --dbType MYSQL

function log {
  date +"[%D-%T] $*"
}


# Parse arguments
while [[ $# -gt 1 ]] ; do
	key="$1"

	case $key in
    	-s|--slaveNumber)
    		SLAVE_NUMBER="$2"
    		shift # past argument
    		;;
    	-d|--dbType)
    		DB_TYPE="$2"
    		shift # past argument
    		;;
		*)
        echo "ERROR: Unexpected argument '${key}'" >&2; exit 1  
    ;;
	esac
	shift 
done

# TODO: Add validation for arguments

# Set default values to arguments
SLAVE_NUMBER=${SLAVE_NUMBER:-1}
DB_TYPE=${DB_TYPE:-MYSQL}

log "Creating network"
# docker network create -d bridge --gateway 172.29.199.200 --subnet 172.29\.199.0/24 --aux-address "DefaultGatewayIPv4=172.29.199.1" network1

log "Starting ${DB_TYPE} database server"
# docker run -d --name db --net network1 --ip 172.29.199.10 --env MYSQL_ROOT_PASSWORD=root --env MYSQL_DATABASE=commander --publish 3306:3306 mysql:latest

log "Creating ${SLAVE_NUMBER} slaves"
for (( i = 1; i <= $SLAVE_NUMBER; i++ )); do
	log "Starting slave$i"
	CID=$(docker run --name slave$i --net network1 --link db:mysql --volume $(pwd):/data --publish 443:443 -dit vmaksimenko/ecloud:slave);
	docker inspect $CID
done

log "Run Haproxy and Zookeeper Server"
# docker run -d --name zookeeper --restart always jplock/zookeeper.out
# docker run -dit --name haproxy --net network1  --publish 1936:1936 haproxy

log "Install commander"
# ...

log "Waiting for nodes up"
# ...

log "Move first node to cluster"
# ...

log "Move other nodes to cluster"
# ...








#
# HARDCODED IP
#

# Create network 
# docker network create -d bridge --gateway 172.29.199.200 --subnet 172.29\.199.0/24 --aux-address "DefaultGatewayIPv4=172.29.199.1" network1

# Run db server
# docker run -d --name db --net network1 --ip 172.29.199.10 --env MYSQL_ROOT_PASSWORD=root --env MYSQL_DATABASE=commander --publish 3306:3306 mysql:latest

# Run Haproxy
# docker run -dit --name haproxy --net network1 --ip 172.29.199.11 --publish 1936:1936 haproxy

# Run zkserver
# docker run -d --name zookeeper --restart always jplock/zookeeper

# Run slave
# docker run --name master --net network1 --ip 172.29.199.31 --link db:mysql --volume $(pwd):/data --publish 443:443 -dit slave


# docker run --name master --link db:mysql -v ~/learn_docker/cluster/:/data -p 443:443 -dit slave


# Install commander 
