FROM php:8.4-fpm-bookworm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    zip \
    unzip \
    nginx \
    supervisor

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_pgsql pgsql mbstring exif pcntl bcmath gd

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy nginx configuration
COPY nginx/nginx.conf /etc/nginx/sites-available/default

# Copy supervisor configuration
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create system user to run Composer and Artisan Commands
RUN useradd -G www-data,root -u 1000 -d /home/laravel laravel
RUN mkdir -p /home/laravel/.composer && \
    chown -R laravel:laravel /home/laravel

# Set permissions
RUN chown -R laravel:www-data /var/www/html

# Expose port 80
EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
