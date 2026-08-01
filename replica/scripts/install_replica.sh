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
# ПЕРЕМЕННЫЕ И НАСТРОЙКИ
# ============================================================
MASTER_IP="192.168.0.148"
ROOT_PASS="TestPass!" # Пароль для root на этом slave-сервере

MYSQL_DEB="${REAL_HOME}/packages/mysql-server-8.0_8.0.46-0ubuntu0.24.04.3_amd64.deb"
MYSQL_NEW_CONFIG="${REAL_HOME}/linux_basic_project/configs/mysqld.cnf" # Убедитесь, что имя файла совпадает (у коллеги было mysqld_slave.cnf)
MYSQL_TARGET_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"

BACKUP_SCRIPT_SRC="${REAL_HOME}/linux_basic_project/scripts/db_backup.sh"
BACKUP_SCRIPT_DST="/etc/cron.daily/db_backup"

# Проверка наличия файлов перед стартом
for file in "$MYSQL_DEB" "$MYSQL_NEW_CONFIG"; do
    if [ ! -f "$file" ]; then
        echo "Ошибка: Файл не найден: $file"
        exit 1
    fi
done

# ============================================================
# 1. УСТАНОВКА И КОНФИГУРАЦИЯ MYSQL
# ============================================================
echo "Установка MySQL Server 8.0..."
apt install "$MYSQL_DEB" -y

echo "Копирование конфигурации реплики..."
cp "$MYSQL_NEW_CONFIG" "$MYSQL_TARGET_CONFIG"

echo "Включение и перезапуск службы MySQL..."
systemctl enable --now mysql
systemctl restart mysql

if ! systemctl is-active --quiet mysql; then
    echo "Ошибка: Служба MySQL не запустилась."
    exit 1
fi

# ============================================================
# 2. УСТАНОВКА ПАРОЛЯ ROOT
# ============================================================
echo "Настройка безопасности пользователя root..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '${ROOT_PASS}';"

# Создаем файл авто-авторизации для root (он необходим и для работы скрипта бэкапа)
echo -e "[client]\nuser=root\npassword='${ROOT_PASS}'" > /root/.my.cnf
chmod 600 /root/.my.cnf

# ============================================================
# 3. НАСТРОЙКА РЕПЛИКАЦИИ
# ============================================================
echo "Настройка и запуск репликации с Мастером (${MASTER_IP})..."
# Теперь все команды mysql автоматически используют пароль из /root/.my.cnf
mysql -e "STOP REPLICA;" || true
mysql -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='${MASTER_IP}', SOURCE_USER='repl', SOURCE_PASSWORD='TestPass!', SOURCE_AUTO_POSITION = 1, GET_SOURCE_PUBLIC_KEY = 1;"
mysql -e "START REPLICA;"

echo "=== Статус репликации ==="
mysql -e "SHOW REPLICA STATUS\G"
echo "========================="

# ============================================================
# 4. НАСТРОЙКА ПОТАБЛИЧНОГО БЭКАПА
# ============================================================
echo "Создание директории для бэкапов /var/db-backup..."
mkdir -p /var/db-backup
chmod 700 /var/db-backup

echo "Настройка планировщика бэкапов..."
if [ -f "$BACKUP_SCRIPT_SRC" ]; then
    cp "$BACKUP_SCRIPT_SRC" "$BACKUP_SCRIPT_DST"
else
    echo "Предупреждение: Файл $BACKUP_SCRIPT_SRC не найден. Скрипт бэкапа будет создан автоматически."
    # Если файла db_backup.sh не было в папке, мы создадим его сами (код ниже в Шаге 2)
fi

# Назначаем права на исполнение для cron
chmod 755 "$BACKUP_SCRIPT_DST"

echo "============================================================"
echo "Настройка сервера DB-SLAVE успешно завершена!"
echo "============================================================"
