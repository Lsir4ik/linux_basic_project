#!/bin/bash

# Завершать скрипт немедленно, если любая команда завершилась ошибкой
set -e

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Нужны повышенные привилегии, используйте: sudo $0"
    exit 1
fi

# Вычисляем правильный домашний каталог пользователя, запустившего sudo
REAL_HOME=$(eval echo "~${SUDO_USER:-$USER}")

# Объявляем пути к файлам через $REAL_HOME
# Пакет лежит в ~/linux_basic_project/ по вашему условию
DEB_PACKAGE="${REAL_HOME}/packages/apache2_2.4.58-1ubuntu8.15_amd64.deb"
NEW_CONFIG="${REAL_HOME}/linux_basic_project/configs/000-default.conf"
NEW_STATIC="${REAL_HOME}/linux_basic_project/static/index.html"

TARGET_CONFIG="/etc/apache2/sites-available/000-default.conf"
TARGET_STATIC_DIR="/var/www/html"

# Проверка наличия deb-пакета
if [ ! -f "$DEB_PACKAGE" ]; then
    echo "Ошибка: Пакет не найден по пути: $DEB_PACKAGE"
    exit 1
fi

echo "============================================================"
echo "Установка Apache2 из локального пакета"
echo "============================================================"
apt install "$DEB_PACKAGE" -y

echo "============================================================"
echo "Копирование файла конфигурации"
echo "============================================================"
if [ -f "$NEW_CONFIG" ]; then
    cp "$NEW_CONFIG" "$TARGET_CONFIG"
else
    echo "Ошибка: Файл конфигурации $NEW_CONFIG не найден!"
    exit 1
fi

echo "============================================================"
echo "Обновление статических файлов (index.html)"
echo "============================================================"
if [ -f "$NEW_STATIC" ]; then
    # Очищаем дефолтную директорию и копируем ваш index.html
    mkdir -p "$TARGET_STATIC_DIR"
    cp "$NEW_STATIC" "${TARGET_STATIC_DIR}/index.html"
    
    # Выставляем правильные права для веб-сервера (чтение для всех)
    chown -R www-data:www-data "$TARGET_STATIC_DIR"
    chmod 644 "${TARGET_STATIC_DIR}/index.html"
else
    echo "Предупреждение: Статический файл $NEW_STATIC не найден, пропускаем."
fi

echo "Проверка синтаксиса конфигурации Apache2..."
apache2ctl configtest

echo "============================================================"
echo "Включение и перезапуск службы Apache2"
echo "============================================================"
systemctl enable --now apache2
systemctl restart apache2

# Проверяем, что служба успешно запустилась и работает
if systemctl is-active --quiet apache2; then
    echo "Служба Apache2 успешно запущена!"
else
    echo "Ошибка: Служба Apache2 не смогла запуститься."
    exit 1
fi

echo "============================================================"
echo "Установка и настройка Apache2 успешно завершены."
echo "============================================================"
