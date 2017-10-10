FROM nginx:1.10.2

ADD start.sh /start.sh
CMD [ "sh", "/start.sh" ]
RUN rm /etc/nginx/conf.d/*

# This file is used by the start script to substitute Templates
#
# Currently known Templates:
# SERVER_URL: served url
COPY laravel.conf.tpl /etc/nginx/conf.template.d/999-laravel.conf.tpl
RUN mkdir -p /var/www/app

RUN mkdir -p /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive


ENV LC_ALL=C
ENV LANG=C
RUN gpg --keyserver keys.gnupg.net --recv-key 89DF5277 && gpg -a --export 89DF5277 \
			| apt-key add - && \
			echo "deb http://ftp.hosteurope.de/mirror/packages.dotdeb.org/ jessie all" \
						> /etc/apt/sources.list.d/dotdeb.list
RUN apt-get update && apt-cache search php7 && apt-get -y install php7.0-mysql \
		coreutils php7.0-fpm php7.0-json php7.0-mbstring \
		php7.0-xml php7.0-zip \
		php7.0-cli php7.0-curl php7.0-gmp php7.0-mcrypt libphp-predis \
		php7.0-imagick php7.0-intl \
		php7.0-gd \
		mysql-client locales \
		&& rm -Rf /var/lib/apt/lists \
		&& ln -s /dev/stderr /var/log/fpm-php.log
RUN localedef -i de_DE -f UTF-8 de_DE.UTF-8
ENV LC_ALL=de_DE.UTF-8
ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de_DE.UTF-8

# Has to be after the installation or dpkg tries to ask about the existing file
ADD nginx.conf.tpl /opt/config/nginx.conf.tpl
ADD www.conf.tpl /opt/config/www.conf.tpl

COPY include /etc/nginx/include
