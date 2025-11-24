FROM php:8.4-fpm-bookworm

# Set working directory
ARG PROJECT_ROOT=/var/www/html
RUN mkdir -p $PROJECT_ROOT
WORKDIR $PROJECT_ROOT

# Set timezone
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Update and get PostgreSQL 17 installer
RUN apt-get update --fix-missing && \
     apt install -y wget gnupg2 lsb-release && \
     sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
     wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Install packages
RUN apt-get update --fix-missing && \
    apt install build-essential nginx-extras git curl supervisor vim locales libicu-dev zip unzip libzip-dev \
        libpq-dev postgresql-client-17 -y

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_pgsql opcache bcmath pcntl intl zip
RUN MAKEFLAGS="-j $(nproc)" pecl install xdebug redis
RUN docker-php-ext-enable opcache redis

# Set locale
RUN echo 'bg_BG.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# www folder owned by www-data
RUN chown -R www-data:www-data /var/www

# Prepare php.ini
COPY config/php/default.ini /usr/local/etc/php/conf.d/00-default.ini

# php-fpm config
RUN rm -rf /usr/local/etc/php-fpm.d
COPY config/php/fpm /usr/local/etc/php-fpm.d

# Supervisord
COPY config/supervisor /etc/supervisor

# Nginx
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.vh.conf /etc/nginx/conf.d/default.conf

# xDebug
RUN mkdir -p /home/xdebug
COPY config/xdebug/xdebug-on.ini /home/xdebug/xdebug-on.ini
COPY config/xdebug/xdebug-off.ini /home/xdebug/xdebug-off.ini

# Create required log directories and set permissions
RUN mkdir -p /var/log/supervisor /var/log/nginx /var/log/php-fpm /var/log/php && \
    chown -R root:www-data /var/log/supervisor /var/log/nginx /var/log/php-fpm /var/log/php && \
    chmod -R 2775 /var/log/supervisor /var/log/nginx /var/log/php-fpm /var/log/php && \
    touch /var/log/supervisor/supervisord.log /var/log/php-fpm/php-fpm.err.log /var/log/php-fpm/php-fpm.out.log \
          /var/log/nginx/nginx.err.log /var/log/nginx/nginx.out.log && \
    chown root:www-data /var/log/supervisor/supervisord.log /var/log/php-fpm/php-fpm.err.log \
      /var/log/php-fpm/php-fpm.out.log /var/log/nginx/nginx.err.log /var/log/nginx/nginx.out.log

# Clear cache to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Prepare entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
