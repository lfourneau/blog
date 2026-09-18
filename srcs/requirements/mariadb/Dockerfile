FROM debian:bookworm

ARG USR_INF

ENV USR_INF=$USR_INF

COPY ./tools/set-up.sh ./tools/set-up.sh
COPY ./conf/50-server.cnf /conf/50-server.cnf 

RUN apt-get update && apt-get -y install mariadb-server mariadb-client galera-4

RUN mariadb-install-db --datadir=/home/${USR_INF}/data --user=mysql

EXPOSE 3306

CMD ["bash", "./tools/set-up.sh"]
