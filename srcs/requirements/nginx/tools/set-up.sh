#!/usr/bin/bash

echo THE ENVIRONMENT VARIABLE: $USR_INF 

if grep '$USR_INF' /etc/nginx/nginx.conf; then
       envsubst i'$USR_INF' < /etc/nginx/nginx.conf > /tmp/nginx.conf
       mv /tmp/nginx.conf /etc/nginx/nginx.conf
fi       

echo "check file is ok"

cat /etc/nginx/nginx.conf

echo "end check"

#create a directory to hold the certificates
if [ ! -d /etc/nginx/ssl ]; then
	mkdir -p /etc/nginx/ssl
	openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/ssl/private.key \
	-out /etc/nginx/ssl/certificate.crt -days 365 -nodes \
	-subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/CN=${HOSTNAME_SSL}" \
	-addext "subjectAltName=DNS:${USR_INF}.42.fr,DNS:www.${USR_INF}.42.fr" \
	-addext "basicConstraints=critical,CA:FALSE" -addext "extendedKeyUsage=serverAuth"
fi

nginx -t

if pgrep -a nginx > /dev/null; then
	pkill nginx 
	echo "shutting down nginx (non pid1)"
fi

exec nginx -g "daemon off;"
