FROM debian:bookworm

EXPOSE 9000

ARG USR_INF

ENV USR_INF=$USR_INF

RUN apt-get update && \
    apt-get install -y \
        wget \
        tar \
        php \
        php-fpm \
        php-mysql \
		curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/$USR_INF/data

RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    rm latest.tar.gz

COPY ./conf/wp-config.php /home/$USR_INF/data/wordpress/wp-config.php
COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY ./tools/set-up.sh /tools/set-up.sh

RUN chown -R www-data:www-data /home/$USR_INF/data/wordpress && \
    chmod +x /tools/set-up.sh

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp && \
    wp --info --allow-root

CMD ["/tools/set-up.sh"]
