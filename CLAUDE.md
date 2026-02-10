# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Table of Contents

- [Project Overview](#project-overview)
- [Common Commands](#common-commands)
- [Architecture & Key Dependencies](#architecture--key-dependencies)
  - [Core](#core)
  - [API & Documentation](#api--documentation)
  - [Document & Image Processing](#document--image-processing)
  - [Utilities](#utilities)
  - [Dev Dependencies](#dev-dependencies)
- [Custom Autoloading](#custom-autoloading)
  - [Libraries в lib/](#libraries-в-lib-кастомные-не-из-composer)
  - [Libraries с кастомными PSR-4 путями в vendor/](#libraries-с-кастомными-psr-4-путями-в-vendor)
- [Required PHP Extensions](#required-php-extensions)
- [TODO: Docker-окружение](#todo-docker-окружение)
  - [Стек](#стек)
  - [Требования](#требования)
  - [Файловая структура](#файловая-структура-ожидаемая)
  - [Важные нюансы](#важные-нюансы)
- [TODO: Миграция на PHP 7.4](#todo-миграция-на-php-74)
  - [PHPStorm — PHP Compatibility Inspection](#способ-1-phpstorm--php-compatibility-inspection)
  - [Rector (автоматический рефакторинг)](#способ-2-rector-автоматический-рефакторинг)
  - [Известные риски при миграции 7.3 → 7.4](#известные-риски-при-миграции-73--74)
  - [Порядок действий](#порядок-действий)

## Project Overview

Laravel 6 REST API project (PHP 7.3). The project name is **vkm-api**.

- **PHP**: 7.3 (composer.json указывает `^7.2`, фактически используется 7.3)
- **Framework**: Laravel 6.x
- **Database**: MariaDB 10.3.6+

## Common Commands

```bash
# Install dependencies
composer install

# Run the application
php artisan serve

# Run all tests
./vendor/bin/phpunit

# Run a single test file
./vendor/bin/phpunit tests/Feature/ExampleTest.php

# Run a single test method
./vendor/bin/phpunit --filter testMethodName

# Database migrations
php artisan migrate
php artisan migrate:rollback

# Seed database
php artisan db:seed

# Generate Swagger/OpenAPI docs
php artisan l5-swagger:generate

# Clear caches
php artisan config:clear
php artisan cache:clear
php artisan route:clear
```

## Architecture & Key Dependencies

### Core

- **Framework**: `laravel/framework` ^6.0
- **Authentication**: `laravel/passport` ^7.4 (OAuth2) + `adldap2/adldap2-laravel` ^6.0 (LDAP/Active Directory)
- **UI**: `laravel/ui` ^1.0
- **HTTP Client**: `guzzlehttp/guzzle` ^6.5
- **Proxy**: `fideloper/proxy` ^4.0

### API & Documentation

- **Swagger/OpenAPI**: `darkaonline/l5-swagger` ^6.0 (annotations in controllers)
- **Popover tooltips**: `andcarpi/laravel-popper` ^0.9.4

### Document & Image Processing

- **Excel**: `maatwebsite/excel` ^3.1.17
- **Word**: `phpoffice/phpword` 0.17.0 (+ `phpoffice/common` 0.2.9)
- **Image**: `intervention/image` ^2.5
- **PDF (Snappy)**: `Barryvdh\Snappy` и `Knp\Snappy` — загружены через custom PSR-4 пути в vendor/

### Utilities

- **AWS**: `aws/aws-sdk-php-laravel` ~3.9
- **Slugs**: `cviebrock/eloquent-sluggable` ^6.0
- **User Agent Detection**: `jenssegers/agent` ^2.6
- **QR Codes**: Custom libraries в `lib/` (laravel-qr-code, qr-code) + `SimpleSoftwareIO\QrCode` и `BaconQrCode` (custom PSR-4 из vendor/)
- **Escaper**: `zendframework/zend-escaper` 2.6.1

### Dev Dependencies

- **Testing**: `phpunit/phpunit` ^8.0, `mockery/mockery` ^1.0
- **Debugging**: `barryvdh/laravel-debugbar` ^3.2, `facade/ignition` ^1.4
- **Faker**: `fzaninotto/faker` ^1.4
- **Error Handling**: `nunomaduro/collision` ^3.0

## Custom Autoloading

Проект содержит нестандартную загрузку через `composer.json` autoload:

### Libraries в `lib/` (кастомные, не из composer)
- `LaravelQRCode\` → `lib/laravel-qr-code/src`
- `QR_Code\` → `lib/qr-code/src/QR_Code`
- Helper files: `lib/qr-code/src/helpers/constants.php`, `lib/qr-code/src/helpers/functions.php`

### Libraries с кастомными PSR-4 путями в `vendor/`
- `SimpleSoftwareIO\QrCode\` → `vendor/simple-qrcode/src`
- `BaconQrCode\` → `vendor/bacon-qrcode/src`
- `DASPRiD\Enum\` → `vendor/enum/src`
- `Barryvdh\Snappy\` → `vendor/laravel-snappy/src`
- `Knp\Snappy\` → `vendor//snappy/src/Knp/Snappy` (двойной слеш в пути — legacy)

**Важно**: Эти пакеты НЕ установлены через composer require, а размещены вручную. При `composer install` они не скачиваются автоматически. При настройке Docker необходимо убедиться, что эти директории присутствуют в vendor/.

## Required PHP Extensions

curl, dom, json, simplexml, soap, libxml

---

## TODO: Docker-окружение

### Задача

Поднять и настроить Docker-окружение для проекта со следующими сервисами:

### Стек

| Сервис    | Образ / Версия                          | Примечания                                    |
|-----------|-----------------------------------------|-----------------------------------------------|
| **nginx** | `nginx:stable-alpine`                   | Reverse proxy → php-fpm:9000                  |
| **php-fpm** | `php:7.3-fpm` (максимальная 7.3.x)   | Все extensions из composer.json               |
| **mysql** | `mariadb:10.3` или выше                 | MySQL Ver 15.1 Distrib 10.3.6-MariaDB совместимый |

### Требования

1. **docker-compose.yml** с сервисами: `nginx`, `php-fpm`, `mysql`
2. **Dockerfile для php-fpm**:
   - Базовый образ `php:7.3-fpm` (последний доступный 7.3.x patch)
   - Установка PHP extensions: `curl`, `dom`, `json`, `simplexml`, `soap`, `libxml`, `pdo_mysql`, `mbstring`, `gd`, `zip`, `bcmath`, `ldap`, `xml`, `tokenizer`, `fileinfo`, `exif`
   - Установка `composer` (v2)
   - `composer install --no-dev --optimize-autoloader` при сборке
   - Wkhtmltopdf для Snappy (если используется PDF-генерация)
3. **Конфигурация nginx**: `default.conf` для проксирования на php-fpm, root → `public/`
4. **Volumes**:
   - Код приложения → `/var/www/html`
   - MySQL data → persistent volume
   - nginx config → bind mount
5. **Environment variables**: через `.env` или `docker-compose.yml` environment section
6. **Network**: единая внутренняя сеть для всех сервисов

### Файловая структура (ожидаемая)

```
docker/
├── nginx/
│   └── default.conf
├── php/
│   └── Dockerfile
├── mysql/
│   └── (init scripts если нужны)
docker-compose.yml
.dockerignore
```

### Важные нюансы

- Библиотеки в `vendor/` с кастомными PSR-4 путями (simple-qrcode, bacon-qrcode, enum, laravel-snappy, snappy) должны быть доступны в контейнере. Если они не установлены через composer, их нужно скопировать вместе с кодом.
- Libraries в `lib/` — часть репозитория, копируются автоматически.
- `minimum-stability: dev` в composer.json — учесть при `composer install`.

---

## TODO: Миграция на PHP 7.4

### Цель

Оценить и провести миграцию с PHP 7.3 на PHP 7.4 для использования typed properties, arrow functions, preloading и других улучшений.

### Способ 1: PHPStorm — PHP Compatibility Inspection

1. **Settings** → **PHP** → установить PHP Language Level на **7.4**
2. **Settings** → **Editor** → **Inspections** → включить **PHP** → **Code Compatibility**:
   - "PHP language level migration" — находит устаревшие конструкции
   - "Deprecated PHP feature" — показывает deprecated функции
3. Запустить **Code** → **Inspect Code...** на весь проект
4. Просмотреть результаты в панели **Inspection Results**, фильтруя по severity
5. PHPStorm покажет несовместимости с 7.4: deprecated функции, изменения в поведении

### Способ 2: Rector (автоматический рефакторинг)

1. Установить Rector:
   ```bash
   composer require --dev rector/rector
   ```
2. Создать `rector.php` в корне проекта:
   ```php
   use Rector\Config\RectorConfig;
   use Rector\Set\ValueObject\LevelSetList;

   return RectorConfig::configure()
       ->withPaths([__DIR__ . '/app', __DIR__ . '/routes', __DIR__ . '/config'])
       ->withSets([LevelSetList::UP_TO_PHP_74]);
   ```
3. Сначала dry-run для просмотра изменений:
   ```bash
   vendor/bin/rector process --dry-run
   ```
4. Применить изменения:
   ```bash
   vendor/bin/rector process
   ```

### Известные риски при миграции 7.3 → 7.4

- `array_merge()` в циклах — Rector предложит spread operator `[...$a, ...$b]`
- Deprecated: `{}` для доступа к символам строки → заменить на `[]`
- `implode()` — порядок аргументов (`implode($glue, $array)` стал обязательным)
- `money_format()` удалена — если используется, заменить на `NumberFormatter`
- Изменения в `array_key_exists()` для объектов — заменить на `isset()` или `property_exists()`
- Зависимости проекта (`adldap2`, `maatwebsite/excel`, `phpoffice/phpword` и др.) — проверить совместимость версий с PHP 7.4

### Порядок действий

1. Проверить совместимость всех composer-зависимостей с PHP 7.4
2. Запустить PHPStorm Inspect Code для обзора проблем
3. Запустить Rector в dry-run режиме
4. Применить автоматические исправления Rector
5. Обновить `composer.json`: `"php": "^7.4"`
6. Запустить тесты (`phpunit`)
7. Обновить Docker-образ на `php:7.4-fpm`
