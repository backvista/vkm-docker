#!/bin/bash
set -e

VENDOR_DIR="/var/www/html/vendor"
APP_DIR="/var/www/html"

# Файл для хранения контрольной суммы composer.json + composer.lock
# Лежит внутри vendor-тома, чтобы переживать перезапуски контейнера
CHECKSUM_FILE="$VENDOR_DIR/.composer_checksum"

# --- Функция: установка/обновление зависимостей через Composer ---
# Используем composer update вместо composer install, потому что:
# composer.lock содержит захардкоженные dist URL на github.com/api.github.com,
# а composer install скачивает пакеты именно по этим URL, игнорируя настроенный репозиторий.
# composer update резолвит пакеты заново через Nexus-зеркало
# и генерирует актуальный composer.lock с правильными URL.
run_composer_install() {
    echo "[entrypoint] Запускаю composer update..."

    # --no-scripts: пропускаем post-autoload-dump хуки (php artisan package:discover),
    # потому что Laravel при discover загружает ВСЕ Artisan-команды, а некоторые из них
    # (например CalculateHandleLoad) обращаются к БД в конструкторе.
    # На этом этапе таблиц ещё может не быть — миграции запустятся ниже.
    composer update --no-scripts --no-interaction --prefer-dist --optimize-autoloader

    # Генерируем autoload без запуска скриптов
    composer dump-autoload --optimize --no-scripts

    # Сохраняем контрольную сумму после успешной установки
    save_checksum

    echo "[entrypoint] composer update завершён."
}

# --- Функция: вычисление контрольной суммы composer-файлов ---
# Считает md5 от содержимого composer.json и composer.lock (если есть)
calculate_checksum() {
    local checksum=""
    if [ -f "$APP_DIR/composer.json" ]; then
        checksum=$(md5sum "$APP_DIR/composer.json" 2>/dev/null | cut -d' ' -f1)
    fi
    if [ -f "$APP_DIR/composer.lock" ]; then
        local lock_checksum
        lock_checksum=$(md5sum "$APP_DIR/composer.lock" 2>/dev/null | cut -d' ' -f1)
        checksum="${checksum}_${lock_checksum}"
    fi
    echo "$checksum"
}

# --- Функция: сохранение контрольной суммы в файл ---
save_checksum() {
    local current_checksum
    current_checksum=$(calculate_checksum)
    echo "$current_checksum" > "$CHECKSUM_FILE"
}

# --- Функция: проверка, изменились ли composer-файлы ---
# Возвращает 0 (true) если файлы изменились или контрольная сумма отсутствует
composer_files_changed() {
    local current_checksum
    current_checksum=$(calculate_checksum)

    # Если файл с контрольной суммой не существует — считаем что изменилось
    if [ ! -f "$CHECKSUM_FILE" ]; then
        return 0
    fi

    local stored_checksum
    stored_checksum=$(cat "$CHECKSUM_FILE")

    # Сравниваем текущую и сохранённую суммы
    if [ "$current_checksum" != "$stored_checksum" ]; then
        return 0
    fi

    # Файлы не изменились
    return 1
}

# === Основная логика ===

# Создаём директорию vendor, если её нет (первый запуск с пустым томом)
mkdir -p "$VENDOR_DIR"

if [ ! -f "$VENDOR_DIR/autoload.php" ]; then
    # Случай 1: vendor-том пустой — полная установка
    echo "[entrypoint] vendor/autoload.php не найден — первичная установка зависимостей."
    run_composer_install
elif composer_files_changed; then
    # Случай 2: composer.json или composer.lock изменились — переустановка
    echo "[entrypoint] Обнаружены изменения в composer.json/composer.lock — переустановка зависимостей."
    run_composer_install
else
    # Случай 3: зависимости актуальны — пропускаем
    echo "[entrypoint] Composer актуален, пропускаю composer install."
fi

# Установка прав доступа для директорий Laravel storage и cache
# www-data — пользователь, от имени которого работает php-fpm
chown -R www-data:www-data "$APP_DIR/storage" "$APP_DIR/bootstrap/cache" 2>/dev/null || true
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache" 2>/dev/null || true

# Миграции БД — создаём таблицы перед запуском приложения
# --force: обязателен для не-local окружений (Laravel блокирует миграции без него)
echo "[entrypoint] Запускаю миграции БД..."
cd "$APP_DIR"
php artisan migrate --force 2>/dev/null || echo "[entrypoint] ВНИМАНИЕ: миграции завершились с ошибкой (возможно БД ещё не готова)"

# package:discover — регистрация сервис-провайдеров пакетов
# Запускаем ПОСЛЕ миграций, т.к. некоторые Artisan-команды обращаются к БД в конструкторе
echo "[entrypoint] Запускаю package:discover..."
php artisan package:discover --ansi 2>/dev/null || echo "[entrypoint] ВНИМАНИЕ: package:discover завершился с ошибкой"

echo "[entrypoint] Запускаю php-fpm..."
exec php-fpm
