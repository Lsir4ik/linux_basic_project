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
# Пакеты
JDK_DEB="${REAL_HOME}/packages/default-jdk_2%3a1.21-75+exp1_amd64.deb"
ES_DEB="${REAL_HOME}/packages/elasticsearch_8.17.1_amd64-224190-db972d.deb"
LS_DEB="${REAL_HOME}/packages/logstash_8.17.1_amd64-224190-40c12c.deb"
KB_DEB="${REAL_HOME}/packages/kibana_8.17.1_amd64-224190-42bf22.deb"

# Конфиги основные
CONFIGS_SRC="${REAL_HOME}/linux_basic_project/configs"
ES_CONFIG_SRC="${CONFIGS_SRC}/elasticsearch.yml"
LS_CONFIG_SRC="${CONFIGS_SRC}/logstash.yml"
KB_CONFIG_SRC="${CONFIGS_SRC}/kibana.yml"

# Целевые пути в системе
ES_CONFIG_DST="/etc/elasticsearch/elasticsearch.yml"
LS_CONFIG_DST="/etc/logstash/logstash.yml"
KB_CONFIG_DST="/etc/kibana/kibana.yml"
LS_CONF_DIR="/etc/logstash/conf.d"

# ============================================================
# ПРОВЕРКА НАЛИЧИЯ ВСЕХ ФАЙЛОВ ПЕРЕД СТАРТОМ
# ============================================================
echo "Проверка наличия всех deb-пакетов и файлов конфигурации..."
for file in "$JDK_DEB" "$ES_DEB" "$LS_DEB" "$KB_DEB" "$ES_CONFIG_SRC" "$LS_CONFIG_SRC" "$KB_CONFIG_SRC"; do
    if [ ! -f "$file" ]; then
        echo "Ошибка: Файл не найден: $file"
        exit 1
    fi
done

# ============================================================
# 1. УСТАНОВКА JAVA (DEFAULT-JDK)
# ============================================================
echo "============================================================"
echo "Установка Java (default-jdk) из локального пакета"
echo "============================================================"
# Используем apt install, чтобы он подтянул базовые зависимости Java, если они нужны
apt install default-jdk -y

# ============================================================
# 2. ELASTICSEARCH
# ============================================================
echo "============================================================"
echo "Установка и настройка Elasticsearch"
echo "============================================================"
dpkg -i "$ES_DEB"

echo "Копирование конфигурации Elasticsearch..."
cp "$ES_CONFIG_SRC" "$ES_CONFIG_DST"
chown root:elasticsearch "$ES_CONFIG_DST"
chmod 660 "$ES_CONFIG_DST"

echo "Настройка JVM для Elasticsearch..."
mkdir -p /etc/elasticsearch/jvm.options.d
cat > /etc/elasticsearch/jvm.options.d/jvm.options <<EOF
-Xms1g
-Xmx1g
EOF

echo "Запуск службы Elasticsearch..."
systemctl daemon-reload
systemctl enable --now elasticsearch.service

# ============================================================
# 3. KIBANA
# ============================================================
echo "============================================================"
echo "Установка и настройка Kibana"
echo "============================================================"
dpkg -i "$KB_DEB"

echo "Копирование конфигурации Kibana..."
cp "$KB_CONFIG_SRC" "$KB_CONFIG_DST"
chown root:kibana "$KB_CONFIG_DST"
chmod 660 "$KB_CONFIG_DST"

echo "Запуск службы Kibana..."
systemctl daemon-reload
systemctl enable --now kibana.service

# ============================================================
# 4. LOGSTASH
# ============================================================
echo "============================================================"
echo "Установка и настройка Logstash"
echo "============================================================"
dpkg -i "$LS_DEB"

echo "Копирование основного конфига Logstash..."
cp "$LS_CONFIG_SRC" "$LS_CONFIG_DST"
chown root:logstash "$LS_CONFIG_DST"
chmod 644 "$LS_CONFIG_DST"

# Создание конфигурации пайплайна для обработки логов Nginx
echo "Создание конфигурации Logstash для обработки логов..."
cat > "${LS_CONF_DIR}/logstash-nginx-es.conf" <<'EOF'
input {
    beats {
        port => 5400
    }
}

filter {
 grok {
   match => [ "message" , "%{COMBINEDAPACHELOG}+%{GREEDYDATA:extra_fields}"]
   overwrite => [ "message" ]
 }
 mutate {
   convert => ["response", "integer"]
   convert => ["bytes", "integer"]
   convert => ["responsetime", "float"]
 }
 date {
   match => [ "timestamp" , "dd/MMM/YYYY:HH:mm:ss Z" ]
   remove_field => [ "timestamp" ]
 }
 useragent {
   source => "agent"
 }
}

output {
 elasticsearch {
   hosts => ["http://localhost:9200"]
   #cacert => '/etc/logstash/certs/http_ca.crt'
   #ssl => true
   index => "weblogs-%{+YYYY.MM.dd}"
   document_type => "nginx_logs"
 }
 stdout { codec => rubydebug }
}
EOF

# Выставляем права на папку с пайплайнами, чтобы Logstash мог их прочитать
chown -R logstash:logstash "$LS_CONF_DIR"
chmod 644 "${LS_CONF_DIR}"/*.conf

echo "Запуск службы Logstash..."
systemctl daemon-reload
systemctl enable --now logstash.service

# ============================================================
# ПРОВЕРКА СТАТУСА СЛУЖБ
# ============================================================
echo "============================================================"
echo "Проверка статуса запущенных служб..."
echo "============================================================"
sleep 5 # Небольшая пауза, чтобы службы успели инициализироваться

for service in elasticsearch kibana logstash; do
    if systemctl is-active --quiet "${service}.service"; then
        echo "Служба $service успешно запущена!"
    else
        echo "Предупреждение: Служба $service не отвечает. Проверьте её статус вручную через systemctl status $service"
    fi
done

echo "============================================================"
echo "Установка и настройка стека ELK успешно завершена!"
echo "============================================================"