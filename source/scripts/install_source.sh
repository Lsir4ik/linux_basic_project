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
MYSQL_DEB="${REAL_HOME}/packages/mysql-server-8.0_8.0.46-0ubuntu0.24.04.3_amd64.deb"
MYSQL_NEW_CONFIG="${REAL_HOME}/linux_basic_project/configs/mysqld.cnf"
MYSQL_TARGET_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"
# Путь к дампу базы данных
DB_DUMP="${REAL_HOME}/linux_basic_project/static/emp/employees.sql"

FB_DEB="${REAL_HOME}/packages/filebeat_8.17.1_amd64-224190-a5f894.deb"
FB_NEW_CONFIG="${REAL_HOME}/linux_basic_project/configs/filebeat.yml"
FB_TARGET_CONFIG="/etc/filebeat/filebeat.yml"

# ============================================================
# ПРОВЕРКА НАЛИЧИЯ ВСЕХ ФАЙЛОВ ПЕРЕД СТАРТОМ
# ============================================================
echo "Проверка наличия необходимых файлов..."
for file in "$MYSQL_DEB" "$MYSQL_NEW_CONFIG" "$DB_DUMP" "$FB_DEB" "$FB_NEW_CONFIG"; do
    if [ ! -f "$file" ]; then
        echo "Ошибка: Файл не найден: $file"
        exit 1
    fi
done

# ============================================================
# 1. УСТАНОВКА И НАСТРОЙКА MYSQL
# ============================================================
echo "============================================================"
echo "Установка MySQL Server 8.0 из локального пакета"
echo "============================================================"
apt install "$MYSQL_DEB" -y

echo "Копирование конфигурации MySQL..."
cp "$MYSQL_NEW_CONFIG" "$MYSQL_TARGET_CONFIG"

echo "Включение и запуск службы MySQL..."
systemctl enable --now mysql
systemctl restart mysql

# Проверяем, что MySQL успешно запустился
if ! systemctl is-active --quiet mysql; then
    echo "Ошибка: Служба MySQL не смогла запуститься."
    exit 1
fi

# ============================================================
# 2. НАСТРОЙКА ПОЛЬЗОВАТЕЛЕЙ И ИМПОРТ БАЗЫ ДАННЫХ
# ============================================================
echo "============================================================"
echo "Создание пользователя для репликации..."
echo "============================================================"
# Пока пароль root не изменен, выполняем команды локально через auth_socket без пароля
mysql -e "CREATE USER 'repl'@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'TestPass!';"
mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"

echo "============================================================"
echo "Загрузка учебной базы данных Employees..."
echo "============================================================"
# Переходим в папку с дампом, так как внутри дампа могут быть относительные пути к файлам данных
cd "$(dirname "$DB_DUMP")"
mysql < "$(basename "$DB_DUMP")"

echo "============================================================"
echo "Установка пароля для пользователя root..."
echo "============================================================"
# Задаем надежный пароль для root (замените 'YourStrongRootPass123!' на ваш или оставьте интерактивный read)
ROOT_PASS="TestPass!"

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '${ROOT_PASS}';"

# Создаем файл аутентификации для root, чтобы системные утилиты и бэкапы могли заходить в базу
echo -e "[client]\nuser=root\npassword='${ROOT_PASS}'" > /root/.my.cnf
chmod 600 /root/.my.cnf

# ============================================================
# 3. УСТАНОВКА И НАСТРОЙКА FILEBEAT
# ============================================================
echo "============================================================"
echo "Установка Filebeat из локального пакета"
echo "============================================================"
apt install "$FB_DEB" -y

echo "Копирование конфигурации Filebeat..."
cp "$FB_NEW_CONFIG" "$FB_TARGET_CONFIG"
chown root:root "$FB_TARGET_CONFIG"
chmod 0600 "$FB_TARGET_CONFIG"

echo "Проверка синтаксиса конфигурации Filebeat..."
filebeat test config -c "$FB_TARGET_CONFIG"

echo "Включение и запуск службы Filebeat..."
systemctl enable --now filebeat
systemctl restart filebeat

if systemctl is-active --quiet filebeat; then
    echo "Служба Filebeat успешно запущена!"
else
    echo "Ошибка: Служба Filebeat не смогла запуститься."
    exit 1
fi

echo "============================================================"
echo "Все этапы успешно завершены! MySQL и Filebeat настроены."
echo "============================================================"
