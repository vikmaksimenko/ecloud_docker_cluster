export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID="XE"
export PATH=$ORACLE_HOME/bin:$PATH

echo "Waiting for db ready"
while true ; do
	OUT=$(/etc/init.d/oracle-xe status)

	echo "$OUT" | grep -q "Service \"XE\" has 1 instance(s)."
	IS_XE=$?

	echo "$OUT" | grep -q "Service \"XEXDB\" has 1 instance(s)."
	IS_XEXDB=$?
	
	if [ $IS_XE -ne 1 ] && [ $IS_XEXDB -ne 1 ]; then
		break
	else
		sleep 1
	fi
done

printf "alter system set open_cursors = 1000 scope=both;\n" | sqlplus system/oracle@xe > /dev/null

echo "Altered database"