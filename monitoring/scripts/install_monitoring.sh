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

# ============================================================
# ПЕРЕМЕННЫЕ ПУТЕЙ
# ============================================================
PROM_DEB="${REAL_HOME}/packages/prometheus_2.45.3+ds-2ubuntu0.3_amd64.deb"
PROM_NEW_CONFIG="${REAL_HOME}/linux_basic_project/prometheus.yml"
PROM_TARGET_CONFIG="/etc/prometheus/prometheus.yml"

GRAFANA_DEB="${REAL_HOME}/packages/grafana_12.3.3_21957728731_linux_amd64-224190-b33d09.deb"

# ============================================================
# ПРОВЕРКА НАЛИЧИЯ ВСЕХ ФАЙЛОВ ПЕРЕД СТАРТОМ
# ============================================================
echo "Проверка наличия пакетов и файлов конфигурации..."
for file in "$PROM_DEB" "$PROM_NEW_CONFIG" "$GRAFANA_DEB"; do
    if [ ! -f "$file" ]; then
        echo "Ошибка: Файл не найден: $file"
        exit 1
    fi
done

# ============================================================
# 1. УСТАНОВКА И НАСТРОЙКА PROMETHEUS
# ============================================================
echo "============================================================"
echo "Установка Prometheus из локального пакета"
echo "============================================================"
apt install "$PROM_DEB" -y

echo "Копирование файла конфигурации Prometheus..."
cp "$PROM_NEW_CONFIG" "$PROM_TARGET_CONFIG"

# Выставляем права, чтобы служба prometheus могла читать свой конфиг
chown -R prometheus:prometheus "$PROM_TARGET_CONFIG"

echo "Включение и перезапуск службы Prometheus..."
systemctl enable --now prometheus
systemctl restart prometheus

# Проверяем, что Prometheus успешно запустился
if systemctl is-active --quiet prometheus; then
    echo "Служба Prometheus успешно запущена!"
else
    echo "Ошибка: Служба Prometheus не смогла запуститься."
    exit 1
fi

# ============================================================
# 2. УСТАНОВКА И НАСТРОЙКА GRAFANA
# ============================================================
echo "============================================================"
echo "Устанавливаем и запускаем Grafana"
echo "============================================================"

# Установка необходимых зависимостей для Grafana из репозиториев
apt install -y adduser libfontconfig1 musl

# Установка Grafana через dpkg из правильной папки packages
dpkg -i "$GRAFANA_DEB"

# Запуск службы Grafana по инструкции коллеги
systemctl daemon-reload
systemctl enable --now grafana-server

# Проверяем, что Grafana успешно запустилась
if systemctl is-active --quiet grafana-server; then
    echo "Служба Grafana успешно запущена!"
else
    echo "Ошибка: Служба Grafana не смогла запуститься."
    exit 1
fi

echo "============================================================"
echo "Мониторинг успешно настроен!"
echo "Prometheus доступен на порту :9090"
echo "Grafana доступна на порту :3000 (дефолтный логин/пароль: admin/admin)"
echo "============================================================"
