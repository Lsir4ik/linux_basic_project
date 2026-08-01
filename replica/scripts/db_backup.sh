#!/bin/bash

# Завершать скрипт немедленно при любой ошибке
set -e

# Настройки путей и безопасная авторизация
BACKUP_ROOT="/var/db-backup"
DATE=$(date +"%Y-%m-%d")
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"

# Используем файл авторизации root
MYSQL='/usr/bin/mysql --defaults-file=/root/.my.cnf --skip-column-names'
MYSQLDUMP='/usr/bin/mysqldump --defaults-file=/root/.my.cnf'

# Получаем список баз, строго исключая служебные метаданные
TARGET_DATABASES=$($MYSQL -e "SHOW DATABASES" | grep -Ev "^(Database|information_schema|performance_schema|mysql|sys)$")

# Создаем папку для сегодняшних бэкапов и переходим в нее
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR" || exit 1

# Автоматическое удаление старых папок с бэкапами (старше 7 дней)
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# Цикл по всем найденным базам данных
for db in $TARGET_DATABASES; do

    echo "Ротация базы данных: $db"
    # Создаем изолированную папку для конкретной базы внутри сегодняшнего дня
    mkdir -p "$db"

    # Цикл по всем таблицам внутри текущей базы
    for table in $($MYSQL -e "SHOW TABLES FROM \`${db}\`"); do

        echo "  Архивация таблицы: $table"
        
        # Потабличный дамп с архивацией на лету + защита репликации (--set-gtid-purged=OFF)
        $MYSQLDUMP --add-drop-table --add-locks --create-options --disable-keys \
        --extended-insert --single-transaction --skip-lock-tables --quick \
        --set-charset --events --routines --triggers --set-gtid-purged=OFF \
        "$db" "$table" | gzip -1 > "$db/${db}_${table}.sql.gz"

    done
done

ls -l /var/db-backup/2026-08-01/employees

echo "============================================================"
echo "Все базы данных успешно упакованы потаблично в $BACKUP_DIR"
echo "============================================================"
