FROM php:8.2-apache

# --------------------------------------------------
# Environment
# --------------------------------------------------
ENV APP_ENV=production \
    APP_DEBUG=false \
    DB_CONNECTION=mysql \
    DB_HOST=YOUR_RENDER_DB_HOST \
    DB_PORT=3306 \
    DB_DATABASE=piprapay \
    DB_USERNAME=piprapay \
    DB_PASSWORD=strongpassword \
    HTTPS=on \
    HTTP_X_FORWARDED_PROTO=https \
    SERVER_PORT=443 \
    TZ=UTC

# --------------------------------------------------
# Install System Dependencies
# --------------------------------------------------
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    zip \
    imagemagick \
    default-mysql-client \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    libmagickwand-dev \
    libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# Configure GD
# --------------------------------------------------
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# --------------------------------------------------
# Install PHP Extensions
# --------------------------------------------------
RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    exif \
    gd \
    gmp \
    intl \
    mbstring \
    mysqli \
    opcache \
    pcntl \
    pdo \
    pdo_mysql \
    sockets \
    zip

# --------------------------------------------------
# Install PECL Extensions
# --------------------------------------------------
RUN pecl install imagick redis \
    && docker-php-ext-enable imagick redis

# --------------------------------------------------
# Apache Configuration
# --------------------------------------------------
RUN a2enmod rewrite headers remoteip

RUN echo 'SetEnvIf X-Forwarded-Proto "https" HTTPS=on' \
    > /etc/apache2/conf-available/forwarded-proto.conf \
    && a2enconf forwarded-proto

RUN sed -ri \
    -e '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
    /etc/apache2/apache2.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# --------------------------------------------------
# Copy Application
# --------------------------------------------------
COPY . /var/www/html/

WORKDIR /var/www/html

# --------------------------------------------------
# Permissions
# --------------------------------------------------
RUN mkdir -p /var/www/html/pp-content \
    && mkdir -p /var/www/html/pp-media \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/pp-content \
    && chmod -R 775 /var/www/html/pp-media

# --------------------------------------------------
# Expose Port
# --------------------------------------------------
EXPOSE 80

# --------------------------------------------------
# Start Apache
# --------------------------------------------------
CMD ["apache2-foreground"]
