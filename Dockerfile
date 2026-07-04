FROM php:8.2-apache

# --------------------------------------------------
# Environment
# --------------------------------------------------
ENV APP_ENV=production \
    APP_DEBUG=false \
    TZ=UTC

# --------------------------------------------------
# Install system dependencies
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

# Enable .htaccess
RUN sed -ri \
    -e '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
    /etc/apache2/apache2.conf

# Remove Apache warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# --------------------------------------------------
# Copy Application
# --------------------------------------------------
COPY . /var/www/html/

WORKDIR /var/www/html

# --------------------------------------------------
# Permissions
# --------------------------------------------------
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/pp-content \
    && chmod -R 775 /var/www/html/pp-media

# --------------------------------------------------
# Health Check
# --------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s \
CMD curl -f http://localhost/ || exit 1

# --------------------------------------------------
# Expose Port
# --------------------------------------------------
EXPOSE 80

# --------------------------------------------------
# Start Apache
# --------------------------------------------------
CMD ["apache2-foreground"]
