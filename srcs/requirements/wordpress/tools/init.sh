#!/bin/bash

set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)


until mariadb-admin ping \
	-h mariadb \
	-u"${MYSQL_USER}" \
	-p"${DB_PASSWORD}" \
	--silent
do
	sleep 1
done


mkdir -p /var/www/html
cd /var/www/html

if [ ! -f "wp-settings.php"  ]; then
	wp core download --allow-root
fi

if [ ! -f "wp-config.php" ]; then
	
	wp config create \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost="mariadb:3306" \
		--allow-root
fi

if ! wp core is-installed --allow-root; then
	wp core install \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email \
		--allow-root
fi

if ! wp user get "${WP_USER}" --allow-root > /dev/null 2>&1; then
	wp user create \
		"${WP_USER}" \
		"${WP_USER_EMAIL}" \
		--user_pass="${WP_USER_PASSWORD}" \
		--role=author \
		--allow-root

fi

mkdir -p /run/php

exec php-fpm8.2 -F
