FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libmagickwand-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mysqli mbstring zip exif pcntl bcmath gd \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && a2enmod rewrite headers remoteip \
    && echo 'SetEnvIf X-Forwarded-Proto "https" HTTPS=on' > /etc/apache2/conf-available/forwarded-proto.conf \
    && a2enconf forwarded-proto \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/pp-content \
    && chmod -R 777 /var/www/html/pp-media
