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

# Безопасно объявляем пути к файлам через $REAL_HOME
DEB_PACKAGE="${REAL_HOME}/packages/filebeat_8.17.1_amd64-224190-a5f894.deb"
NEW_CONFIG="${REAL_HOME}/linux_basic_project/configs/filebeat.yml"
TARGET_CONFIG="/etc/filebeat/filebeat.yml"

# Проверка наличия deb-пакета
if [ ! -f "$DEB_PACKAGE" ]; then
    echo "Ошибка: Пакет не найден по пути: $DEB_PACKAGE"
    exit 1
fi

echo "============================================================"
echo "Установка Filebeat из локального пакета"
echo "============================================================"
apt install "$DEB_PACKAGE" -y

echo "============================================================"
echo "Копирование файла конфигурации"
echo "============================================================"
if [ -f "$NEW_CONFIG" ]; then
    # Копируем ваш конфиг на место стандартного
    cp "$NEW_CONFIG" "$TARGET_CONFIG"
    
    # Выставляем правильные права (Filebeat строго требует, чтобы у конфига был владелец root и права 0600)
    chown root:root "$TARGET_CONFIG"
    chmod 0600 "$TARGET_CONFIG"
else
    echo "Ошибка: Файл конфигурации $NEW_CONFIG не найден!"
    exit 1
fi

echo "Проверка синтаксиса конфигурации Filebeat..."
filebeat test config -c "$TARGET_CONFIG"

echo "============================================================"
echo "Включение и запуск службы Filebeat"
echo "============================================================"
# Используем restart, чтобы Filebeat точно перечитал новый файл конфигурации
systemctl enable --now filebeat
systemctl restart filebeat

# Проверяем, что служба успешно запустилась и работает
if systemctl is-active --quiet filebeat; then
    echo "Служба filebeat успешно запущена с вашей конфигурацией!"
else
    echo "Ошибка: Служба filebeat не смогла запуститься. Проверьте логи: journalctl -u filebeat"
    exit 1
fi

echo "============================================================"
echo "Установка и настройка Filebeat успешно завершены."
echo "============================================================"
