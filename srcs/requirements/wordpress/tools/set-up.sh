#!/usr/bin/bash

#installation wordpress programs && php modules
#apt-get update && apt-get -y install wget tar php php-fpm php-mysql
#wget https://wordpress.org/latest.tar.gz
#tar -xzvf latest.tar.gz
#rm -rf latest.tar.gz
#
#chown -R www-data:www-data wordpress
#cp wp-config.php ./wordpress/wp-config.php
#rm wp-config.php

wp_adm=$(cat /run/secrets/credentials | grep -w WP_ADMIN | cut -d "=" -f2)
wp_adm_pass=$(cat /run/secrets/credentials | grep -w WP_PASSWORD | cut -d "=" -f2)
wp_adm_email=$(cat /run/secrets/credentials | grep -w WP_ADMIN_EMAIL | cut -d "=" -f2)
wp_usr=$(cat /run/secrets/credentials | grep -w WP_USR | cut -d "=" -f2)
wp_usr_pass=$(cat /run/secrets/credentials | grep -w WP_USR_PASS | cut -d "=" -f2)
wp_usr_email=$(cat /run/secrets/credentials | grep -w WP_USR_EMAIL | cut -d "=" -f2)

PHP_FPM=$(find /usr/sbin -name php-fpm* -type f)	

#shut down to run as main process
#apparently this is useless with docker as launching
#stops all processes and therefore php-fpm can't be on
if pgrep -a php > /dev/null ; then 
	echo php-fpm is running
	echo relaunching
	pkill php-fpm > /dev/null 
fi

if [ -f /home/${USR_INF}/data/wordpress/wp-config-sample.php ]; then
	rm /home/${USR_INF}/data/wordpress/wp-config-sample.php	
fi

if ! wp core is-installed --path=/home/${USR_INF}/data/wordpress --allow-root; then 
	 wp core install --path=/home/${USR_INF}/data/wordpress --allow-root \
	    --url="https://${USR_INF}.42.fr" \
    	--title="Inception" --allow-root \
        --admin_user="$wp_adm" --admin_password="$wp_adm_pass" --admin_email="$wp_adm_email"
    wp user create "$wp_usr" "$wp_usr_email" --role=subscriber --user_pass="$wp_usr_pass" \
        --path=/home/${USR_INF}/data/wordpress --allow-root 
fi;
	

echo "wordpress container is good"

exec ${PHP_FPM} -F   
