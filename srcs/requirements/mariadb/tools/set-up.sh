#!/usr/bin/bash

DATADIR=/home/${USR_INF}/data

wait_maria(){
	while ! mariadb-admin ping --silent; do
		sleep 1
	done
}

# /run/mysqld survives "docker compose stop/start", so always (re)create it
# and remove any stale socket/pid left by the previous run
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
rm -f /run/mysqld/mysqld.sock /run/mysqld/mysqld.pid

if [ ! -d ${DATADIR}/mysql ]; then
	mariadb-install-db --datadir=${DATADIR} --user=mysql
fi

# Only configure the database on first launch: once done, root has a
# password and the WordPress database already exists
if [ ! -d ${DATADIR}/${WORDPRESSDATABASE} ]; then
	echo "First launch: configuring MariaDB"
	mariadbd --defaults-file=/conf/50-server.cnf --datadir=${DATADIR} --user=mysql --skip-networking &
	wait_maria

	cat >database_set_up <<STOP
CREATE DATABASE IF NOT EXISTS ${WORDPRESSDATABASE};
CREATE USER IF NOT EXISTS '${WORDPRESSUSER}'@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';
GRANT ALL PRIVILEGES ON ${WORDPRESSDATABASE}.* TO "${WORDPRESSUSER}"@"%" IDENTIFIED BY '$(cat /run/secrets/db_password)';
DROP USER IF EXISTS ''@'${HOSTNAME}';
DROP USER IF EXISTS ''@'localhost';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_password)';
FLUSH PRIVILEGES;
STOP

	mariadb -u root <database_set_up
	rm database_set_up

	mariadb-admin -u root -p"$(cat /run/secrets/db_root_password)" shutdown
	wait
	echo "MariaDB configured"
else
	echo "MariaDB already configured"
fi

exec mariadbd --defaults-file=/conf/50-server.cnf --datadir=${DATADIR} --user=mysql
