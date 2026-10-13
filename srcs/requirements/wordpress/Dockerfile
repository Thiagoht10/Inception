FROM debian:bookworm

RUN apt-get update && apt-get install -y \
	php-fpm \
	php-mysql \
	mariadb-client \
	curl \
	&& rm -rf /var/lib/apt/list/*

RUN curl -o /usr/local/bin/wp \
	https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

WORKDIR /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/init.sh"]

