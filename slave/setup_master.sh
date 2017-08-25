#/bin/bash

HAPROXY_IP=$1
ZOOKEEPER_IP=$2
DB_TYPE=$3

DATA_DIR=/data
COMMANDER_DIR=/opt/electriccloud/electriccommander

# set -x

# Modify database.properties
cp $DATA_DIR/database.properties $COMMANDER_DIR/conf/database.properties


case "$DB_TYPE" in
	MYSQL)
		# Add mysql_connector to server lib 
		cp $DATA_DIR/mysql-connector-java-* $COMMANDER_DIR/server/lib
		;;
	ORACLE)
		# Disable timezoneAsRegion to prevent ORA-01882: timezone region not found
		TMP=$(mktemp -d)
		cd $TMP
		OJDBC_JAR="$COMMANDER_DIR/server/wars/commander-server.war/WEB-INF/lib/ojdbc.jar"
		unzip $OJDBC_JAR oracle/jdbc/defaultConnectionProperties.properties -d $TMP
		echo "oracle.jdbc.timezoneAsRegion=false" >> oracle/jdbc/defaultConnectionProperties.properties
		zip $OJDBC_JAR oracle/jdbc/defaultConnectionProperties.properties
		cd
		rm -rf $TMP
		;;
	MSSQL)
		;;
	*)
		echo "Unknown option: $DB_TYPE. Use {MYSQL|ORACLE}" > 2
		exit 1
esac

# Modify commander.properties
sed -i.bak s/COMMANDER_SERVER_NAME=.*/COMMANDER_SERVER_NAME=${HAPROXY_IP}/g $COMMANDER_DIR/conf/commander.properties

# Upload file to zookeeper
COMMANDER_ZK_CONNECTION=$ZOOKEEPER_IP:2181 $COMMANDER_DIR/jre/bin/java -jar $COMMANDER_DIR/server/bin/zk-config-tool-jar-with-dependencies.jar com.electriccloud.commander.cluster.ZKConfigTool --commanderPropertiesFile $COMMANDER_DIR/conf/commander.properties --keystoreFile $COMMANDER_DIR/conf/keystore --confSecurityFolder $COMMANDER_DIR/conf/security --databasePropertiesFile $COMMANDER_DIR/conf/database.properties --passkeyFile $COMMANDER_DIR/conf/passkey 
$COMMANDER_DIR/bin/ecconfigure --serverName $ZOOKEEPER_IP --serverZooKeeperConnection ${ZOOKEEPER_IP}:2181

/etc/init.d/commanderServer restart

# wait_for_server
echo "Waiting for server up"
chmod +x /data/wait_for_server.sh && /data/wait_for_server.sh
echo "Commander server is running"

export PATH=$PATH:$COMMANDER_DIR/bin;

ectool login admin changeme

# Set the IP Address of the Commander server to HAproxy.  The
# agents use this address for the finish-command.
ectool setProperty /server/settings/ipAddress ${HAPROXY_IP}

# Stomp
ectool setProperty /server/settings/stompClientUri stomp+ssl://${HAPROXY_IP}:61613
ectool setProperty /server/settings/stompSecure false

# Delete the "local" resource and create a "local" pool.
ectool deleteResource local
ectool deleteResourcePool local
ectool createResourcePool local

# Create a resource and add it to the "local" pool
# hostName=`hostname`
# nodeIp=`grep $(hostname) /etc/hosts|tail -1|cut -f 1`
# ectool deleteResource local_$hostName
# ectool createResource local_$hostName --hostName $nodeIp --pools local

# License
ectool importLicenseData $DATA_DIR/license.xml

# Workspace
chmod 777 /workspace
ectool modifyWorkspace default --agentUnixPath /workspace --local false

# Plugins
cp -r $COMMANDER_DIR/plugins/* /plugins
ectool setProperty "/server/settings/pluginsDirectory" "/plugins"
ectool setProperty "/server/Electric Cloud/unixPluginsShare" "/plugins"
ectool setProperty "/server/Electric Cloud/windowsPluginsShare" "/plugins"
$COMMANDER_DIR/bin/ecconfigure --agentPluginsDirectory "/plugins"

/etc/init.d/commanderServer restart
echo "Waiting for server up"
chmod +x /data/wait_for_server.sh && /data/wait_for_server.sh
echo "Commander server is running"
