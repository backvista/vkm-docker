#!/bin/bash
set -e

VENDOR_DIR="/var/www/html/vendor"
APP_DIR="/var/www/html"

# Файл для хранения контрольной суммы composer.json + composer.lock
# Лежит внутри vendor-тома, чтобы переживать перезапуски контейнера
CHECKSUM_FILE="$VENDOR_DIR/.composer_checksum"

# Кастомные vendor-пакеты, которые НЕ установлены через composer
# Эти пакеты размещены в репозитории вручную и прописаны в autoload через PSR-4
CUSTOM_VENDOR_PACKAGES=(
    "simple-qrcode"
    "bacon-qrcode"
    "enum"
    "laravel-snappy"
    "snappy"
)

# --- Функция: восстановление кастомных vendor-пакетов ---
# Копирует пакеты из _vendor_custom/ в vendor/, если они отсутствуют
restore_custom_packages() {
    for pkg in "${CUSTOM_VENDOR_PACKAGES[@]}"; do
        if [ ! -d "$VENDOR_DIR/$pkg" ] && [ -d "$APP_DIR/_vendor_custom/$pkg" ]; then
            echo "[entrypoint] Восстанавливаю кастомный vendor-пакет: $pkg"
            cp -r "$APP_DIR/_vendor_custom/$pkg" "$VENDOR_DIR/$pkg"
        fi
    done
}

# --- Функция: запуск composer install ---
run_composer_install() {
    echo "[entrypoint] Запускаю composer install..."

    # Сначала восстанавливаем кастомные пакеты (они нужны для autoload)
    restore_custom_packages

    composer install --no-interaction --prefer-dist --optimize-autoloader

    # Сохраняем контрольную сумму после успешной установки
    save_checksum

    echo "[entrypoint] composer install завершён."
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
    # Случай 3: зависимости актуальны — только проверяем кастомные пакеты
    echo "[entrypoint] Composer актуален, пропускаю composer install."
    restore_custom_packages
fi

# Установка прав доступа для директорий Laravel storage и cache
# www-data — пользователь, от имени которого работает php-fpm
chown -R www-data:www-data "$APP_DIR/storage" "$APP_DIR/bootstrap/cache" 2>/dev/null || true
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache" 2>/dev/null || true

echo "[entrypoint] Запускаю php-fpm..."
exec php-fpm
