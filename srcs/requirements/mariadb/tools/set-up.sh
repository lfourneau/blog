#!/usr/bin/bash

wait_maria(){
	while ! mariadb-admin ping --silent; do
		sleep 1
	done
}

if [ ! -d /home/${USR_INF}/data/mysql ]; then 
	mariadb-install-db --datadir=/home/${USR_INF}/data --user=mysql
fi

#apparently this is useless with docker as launching
#stops all processes and therefore mariadb can't be on
if ! pgrep mariadb >/dev/null; then 
	echo "Mariadb is not launched yet"
	if [ ! -d /run/mysqld ]; then
		mkdir -p /run/mysqld
		chown mysql:mysql /run/mysqld
		exec mariadbd --defaults-file=/conf/50-server.cnf --datadir=/home/${USR_INF}/data --user=mysql &
	fi
	wait_maria
	echo "Mariadb is working"	
else 
	echo "Mariadb is working corrrectly"
fi

cat >database_set_up <<STOP 
CREATE DATABASE IF NOT EXISTS ${WORDPRESSDATABASE};
CREATE USER IF NOT EXISTS '${WORDPRESSUSER}'@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';
GRANT ALL PRIVILEGES ON ${WORDPRESSDATABASE}.* TO "${WORDPRESSUSER}"@"%" IDENTIFIED BY '$(cat /run/secrets/db_password)';
DROP USER IF EXISTS ''@'${HOSTNAME}';
DROP USER IF EXISTS ''@'localhost';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_password)';
FLUSH PRIVILEGES;
EXIT
STOP

cat database_set_up

mariadb -u root <database_set_up

mariadb-admin -u root -p"$(cat /run/secrets/db_root_password)" shutdown

rm database_set_up

exec mariadbd --defaults-file=/conf/50-server.cnf --datadir=/home/${USR_INF}/data --user=mysql
