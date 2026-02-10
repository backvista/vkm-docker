#!/bin/bash
set -e

VENDOR_DIR="/var/www/html/vendor"

# Custom vendor packages that are not installed via composer
CUSTOM_VENDOR_PACKAGES=(
    "simple-qrcode"
    "bacon-qrcode"
    "enum"
    "laravel-snappy"
    "snappy"
)

# Install vendor dependencies if vendor volume is empty
if [ ! -f "$VENDOR_DIR/autoload.php" ]; then
    echo "[entrypoint] vendor/autoload.php not found — running composer install..."

    # Copy custom vendor packages from bind mount backup (if available)
    for pkg in "${CUSTOM_VENDOR_PACKAGES[@]}"; do
        if [ -d "/var/www/html/_vendor_custom/$pkg" ]; then
            echo "[entrypoint] Copying custom vendor package: $pkg"
            cp -r "/var/www/html/_vendor_custom/$pkg" "$VENDOR_DIR/$pkg"
        fi
    done

    composer install --no-interaction --prefer-dist --optimize-autoloader

    echo "[entrypoint] composer install completed."
else
    # Ensure custom vendor packages exist even if autoload.php is present
    for pkg in "${CUSTOM_VENDOR_PACKAGES[@]}"; do
        if [ ! -d "$VENDOR_DIR/$pkg" ] && [ -d "/var/www/html/_vendor_custom/$pkg" ]; then
            echo "[entrypoint] Restoring custom vendor package: $pkg"
            cp -r "/var/www/html/_vendor_custom/$pkg" "$VENDOR_DIR/$pkg"
        fi
    done
fi

# Set permissions for Laravel storage and cache
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

echo "[entrypoint] Starting php-fpm..."
exec php-fpm
