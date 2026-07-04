FROM php:8.2-apache

# -----------------------------
# Application Environment
# -----------------------------
ENV APP_ENV=production \
    APP_DEBUG=false \
    DB_CONNECTION=mysql \
    DB_HOST=your-mysql-host \
    DB_PORT=3306 \
    DB_DATABASE=piprapay \
    DB_USERNAME=piprapay \
    DB_PASSWORD=strongpassword \
    HTTPS=on \
    HTTP_X_FORWARDED_PROTO=https \
    SERVER_PORT=443 \
    TZ=UTC

# -----------------------------
# Install system packages
# -----------------------------
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    bcmath \
    zip \
    curl \
    imagemagick \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    libicu-dev \
    libxml2-dev \
    libmagickwand-dev \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Configure and install PHP extensions
# -----------------------------
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

RUN docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo_mysql \
    gd \
    intl \
    zip \
    opcache

RUN pecl install imagick \
    && docker-php-ext-enable imagick

# -----------------------------
# Apache configuration
# -----------------------------
RUN a2enmod rewrite headers remoteip

RUN sed -ri \
    -e 's!/var/www/html!/var/www/html!g' \
    -e '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
    /etc/apache2/apache2.conf

# -----------------------------
# Copy application
# -----------------------------
COPY . /var/www/html/

WORKDIR /var/www/html

# -----------------------------
# Permissions
# -----------------------------
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/pp-content /var/www/html/pp-media

# -----------------------------
# Expose HTTP port
# -----------------------------
EXPOSE 80

# -----------------------------
# Start Apache
# -----------------------------
CMD ["apache2-foreground"]
