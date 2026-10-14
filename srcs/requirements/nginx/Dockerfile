FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes \
	-out /etc/nginx/ssl/inception.crt \
	-keyout /etc/nginx/ssl/inception.key \
	-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=thde-sou.42.fr"

COPY conf/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
