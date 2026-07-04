FROM php:8.2-apache

# ---------------------------------------------------------------------------
# System packages: build deps for PHP extensions + MySQL server + supervisor
# to run apache and mysqld in the same container.
# ---------------------------------------------------------------------------
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
    default-mysql-server \
    supervisor \
    gosu \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mysqli mbstring zip exif pcntl bcmath gd \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && a2enmod rewrite headers remoteip \
    && echo 'SetEnvIf X-Forwarded-Proto "https" HTTPS=on' > /etc/apache2/conf-available/forwarded-proto.conf \
    && a2enconf forwarded-proto \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Apache: Render provides the external port via $PORT, default to 80 locally.
# We rewrite the apache port config at container start (see docker-entrypoint.sh)
# because Apache's ports.conf doesn't expand env vars on its own.
#
# PipraPay's index.php lives at the repo root (confirmed: no public/ subfolder),
# so the document root stays the default /var/www/html -- no rewrite needed.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# App code
# ---------------------------------------------------------------------------
WORKDIR /var/www/html
COPY ./ /var/www/html

# ---------------------------------------------------------------------------
# MySQL data directory. On Render, mount a persistent disk at this path
# (Render Dashboard -> your service -> Disks) or the DB resets on every
# deploy/restart. Without a disk this is ephemeral, same as any container fs.
# ---------------------------------------------------------------------------
ENV MYSQL_DATA_DIR=/var/lib/mysql
RUN mkdir -p ${MYSQL_DATA_DIR} /var/run/mysqld \
    && chown -R mysql:mysql ${MYSQL_DATA_DIR} /var/run/mysqld

# ---------------------------------------------------------------------------
# IMPORTANT: PipraPay (confirmed via its own repo/docs) is a plain-PHP app
# configured through pp_config.php in the install directory, NOT environment
# variables. The DB_* / APP_ENV vars in the original compose file were almost
# certainly inert -- there is no evidence PipraPay reads them. Real DB config
# happens through pp_config.php (edit it before/after copying the app in) or
# through whatever setup wizard the app exposes on first run.
#
# These MySQL bootstrap values are used by docker-entrypoint.sh to create the
# database/user that pp_config.php should then be pointed at -- host 127.0.0.1,
# port 3306, database/user/password as set below. They do not configure the
# app itself.
# ---------------------------------------------------------------------------
ENV DB_DATABASE=piprapay \
    DB_USERNAME=piprapay \
    DB_PASSWORD=strongpassword \
    MYSQL_ROOT_PASSWORD=strongrootpassword \
    HTTPS=on \
    HTTP_X_FORWARDED_PROTO=https

# ---------------------------------------------------------------------------
# PipraPay has no Laravel-style storage/bootstrap/cache convention. Its own
# docs describe editing pp_config.php in place and installing plugins/themes
# through the admin panel, both of which write into the app tree (pp-content,
# pp-media, pp_config.php itself). So the whole tree is made writable by
# www-data rather than guessing at specific subfolders.
# ---------------------------------------------------------------------------
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown -R www-data:www-data /var/www/html

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]
