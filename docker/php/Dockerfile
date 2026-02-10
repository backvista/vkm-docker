# Базовый образ PHP 7.3 с FPM (последний патч 7.3.33)
# Основан на Debian 11 (Bullseye)
FROM nexus.fc.uralsibbank.ru/dockerhub/php:7.3.33-fpm

# === Корпоративный контур: сертификат и зеркало репозиториев ===

# Подкладываем корневой сертификат организации (CA)
# Необходим для работы с внутренним Nexus-зеркалом по HTTPS
COPY ca.pem /usr/local/share/ca-certificates/ca.pem
RUN cat /usr/local/share/ca-certificates/ca.pem >> /etc/ssl/certs/ca-certificates.crt

# Заменяем стандартные репозитории Debian на корпоративное Nexus-зеркало
# Удаляем дефолтный sources.list, чтобы apt не обращался к публичным серверам
COPY debian.sources /etc/apt/sources.list.d/debian.sources
RUN sed -i 's/\r$//' /etc/apt/sources.list.d/debian.sources \
    && rm -f /etc/apt/sources.list

# === Системные зависимости ===

# Библиотеки, необходимые для сборки PHP-расширений
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    libxml2-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libldap2-dev \
    libonig-dev \
    libsodium-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# === PHP-расширения ===

# gd — обработка изображений (с поддержкой freetype и jpeg)
# ldap — аутентификация через Active Directory (adldap2)
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        mbstring \
        xml \
        dom \
        simplexml \
        soap \
        zip \
        gd \
        bcmath \
        ldap \
        tokenizer \
        fileinfo \
        exif \
        opcache

# === wkhtmltopdf ===

# Используется библиотекой Snappy для генерации PDF
# xfonts и fontconfig — шрифты, необходимые для корректного рендеринга PDF
RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    xfonts-75dpi \
    xfonts-base \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# === Composer ===

# Установка Composer v2 (мультистейдж-копирование из официального образа)
COPY --from=nexus.fc.uralsibbank.ru/dockerhub/composer:2 /usr/bin/composer /usr/bin/composer

# Глобальная конфигурация Composer для работы через корпоративный Nexus
# Отключает публичный packagist.org и направляет все запросы через внутреннее зеркало
# SSL: verify_peer=false и allow_self_signed=true — для корпоративного CA
ENV COMPOSER_HOME=/root/.composer
RUN mkdir -p $COMPOSER_HOME
COPY composer-global.json $COMPOSER_HOME/config.json

# Рабочая директория приложения
WORKDIR /var/www/html

# === Entrypoint ===

# Копирование и настройка entrypoint-скрипта
# Скрипт при каждом запуске контейнера:
# 1. Проверяет контрольные суммы composer.json/composer.lock
# 2. Запускает composer install при обнаружении изменений
# 3. Восстанавливает кастомные vendor-пакеты
# 4. Устанавливает права доступа для Laravel
# 5. Запускает php-fpm
# Подстраховка от CRLF: Windows + WSL2 может подложить \r в shell-скрипт,
# что сломает shebang (#!/bin/bash\r → "bad interpreter: No such file or directory")
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Порт FastCGI, на котором слушает php-fpm
EXPOSE 9000

# Точка входа — entrypoint.sh проверяет зависимости и запускает php-fpm
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
