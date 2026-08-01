# Проектная работа: "Проектирование и развертывание отказоустойчивой ИТ-инфраструктуры с автоматическим восстановлением, централизованным мониторингом и логированием"

---

## Описание

Проект представляет собой распределённую веб-платформу, состоящую из 7 независимых серверов. Основная цель — обеспечить быстрое восстановление всей инфраструктуры после сбоя с использованием только этого репозитория и резервных копий баз данных.

Проект является учебным и демонстрирует навыки автоматизации развёртывания и планирования восстановления.

Репозиторий содержит скрипты, конфигурационные файлы и документацию для быстрого развёртывания и аварийного восстановления системы.

---

## Схема стенда

![[Linux Basic_schema.drawio.png]]

## Структура репозитория

```text
.
├── nginx/
│   ├── scripts/                        # Папка для скриптов автоматизации
|	│    ├── install_nginx.sh           # Скрипт установки nginx
|	│    ├── install_node_exporter.sh   # Скрипт установки prometheus node exporter
│   │    └── install_filebeat.sh        # Скрипт установки filebeat
│   ├── configs/                        # Папка для файлов конфигурации
|	│   ├── default                     # Конфигурация nginx с reverse proxy и load balancer
|	│   └── filebeat.yml                # Конфигурация filebeat
├── backend1/
│   ├── scripts/                        # Папка для скриптов автоматизации
│   │    └── install_apache2.sh         # Скрипт установки apache2
│   ├── configs/                        # Папка для файлов конфигурации
|	│   └── 000-default.conf            # Конфигурация nginx с reverse proxy и load balancer
│   ├── static/                         # Папка для индексных файлов
|	│   └── index.html                  # Индексный файл с кастомной страницей
├── backend2/
│   ├── scripts/                        # Папка для скриптов автоматизации
│   │    └── install_apache2.sh         # Скрипт установки apache2
│   ├── configs/                        # Папка для файлов конфигурации
|	│   └── 000-default.conf            # Конфигурация nginx с reverse proxy и load balancer
│   ├── static/                         # Папка для индексных файлов
|	│   └── index.html                  # Индексный файл с кастомной страницей
├── source/
│   ├── scripts/                        # Папка для скриптов автоматизации
|	│    └── install_source.sh          # Скрипт установки MySQL, filebeat
│   ├── configs/                        # Папка для файлов конфигурации
|	│   ├── mysqld.cnf                  # Конфигурация MySQL-Source
|	│   └── filebeat.yml                # Конфигурация filebeat
│   ├── static/                         # Папка для индексных файлов
|	│   └── emp                         # Директория с учебной БД MySQL employee
├── replica/
│   ├── scripts/                        # Папка для скриптов автоматизации
|	│    ├── db_backup.sh               # Скрипт потабличного бэкапа БД
|	│    └── install_replica.sh         # Скрипт установки MySQL
│   ├── configs/                        # Папка для файлов конфигурации
|	│   ├── mysqld.cnf                  # Конфигурация MySQL-Replica
├── monitoring/
│   ├── scripts/                        # Папка для скриптов автоматизации
|	│    └── install_monitoring.sh      # Скрипт установки Prometheus, Grafana
│   ├── configs/                        # Папка для файлов конфигурации
|	│   └── prometheus.yml              # Конфигурация Prometheus
├── elk/
│   ├── scripts/                        # Папка для скриптов автоматизации
|	│    ├── install_elk.sh             # Скрипт установки Elasticsearch, Logstash, Kibana
│   ├── configs/                        # Папка для файлов конфигурации
|	│   ├── elasticsearch.yml           # Конфигурация nginx с reverse proxy и load balancer
|	│   ├── logstash.yml                # Конфигурация nginx с reverse proxy и load balancer
|	│   ├── kibana.yml                  # Конфигурация nginx с reverse proxy и load balancer
|	│   ├── logstash-mysql-source.conf  # Пайплайн Logstash для MySQL Source сервера
|	│   └── logstash-nginx-es.conf      # Пайплайн Logstash для Nginx сервера
└── README.md
```

---

<a id="dest"></a>

## Назначение виртуальных машин

| Наименование VM |             Роль             |             Сервисы             |
| :-------------: | :--------------------------: | :-----------------------------: |
|      nginx      | load balancer, reverse proxy | nginx, filebeat, node_exporter  |
|    backend1     |        web-backend №1        |             apache2             |
|    backend2     |        web-backend №2        |             apache2             |
|     master      |         MySQL source         |              mysql              |
|     replica     |        MySQL replica         |              mysql              |
|   monitoring    | централизованный мониторинг  |       prometheus+grafana        |
|       elk       | централизованное логирование | elasticsearch, logstash, kibana |

---

<a id="hw"></a>

## Аппаратные требования и ОС

| Наименование VM | Ядра CPU | RAM, Гб | Диск, Гб | Версия ОС        |
| :-------------: | :------: | :-----: | -------- | ---------------- |
|      nginx      |    1     |    1    | 15       | Ubuntu 22.04 LTS |
|    backend1     |    1     |    1    | 15       | Ubuntu 22.04 LTS |
|    backend2     |    1     |    1    | 15       | Ubuntu 22.04 LTS |
|     master      |    1     |    1    | 15       | Ubuntu 22.04 LTS |
|     replica     |    1     |    1    | 15       | Ubuntu 22.04 LTS |
|   monitoring    |    2     |    2    | 15       | Ubuntu 22.04 LTS |
|       elk       |    4     |    4    | 15       | Ubuntu 22.04 LTS |
|    **ИТОГО**    |    11    |   11    | 105      |                  |

---

<a id="3"></a>

## IP-адресация

| Наименование VM |      IP       | Строка подключения    |
| :-------------: | :-----------: | --------------------- |
|      nginx      | 192.168.0.107 | ssh lsi@192.168.0.107 |
|    backend1     | 192.168.0.244 | ssh lsi@192.168.0.244 |
|    backend2     | 192.168.0.203 | ssh lsi@192.168.0.203 |
|     source      | 192.168.0.148 | ssh lsi@192.168.0.148 |
|     replica     | 192.168.0.169 | ssh lsi@192.168.0.169 |
|   monitoring    | 192.168.0.243 | ssh lsi@192.168.0.243 |
|       elk       | 192.168.0.150 | ssh lsi@192.168.0.150 |

При внесении изменений в IP-адресацию потребуется изменение файлов конфигурации Nginx, MySQL, Prometheus, ELK, filebeat.

---

## Порядок развертывания

## 1. Подготовка

- На хостовой машине необходимо создать 7 виртуальных машин в соответствии с требованиями [Назначение виртуальных машин](#dest), [Аппаратные требования](#hw), [IP-адресация.](#3)
- Установить на все виртуальные машины Ubuntu Server 24.04.
- Установить пакет openssh-server для подключения по ssh, добавить открытый ключ машины, с которой планируете проводить работы

```
sudo -i #pass
apt update
apt install opessh-server -y
nano ~/.ssh/authorized_keys #paste .pub key
```

- Установить местное время

```
sudo timedatectl set-timezone Europe/Saratov
```

- Установить git на все VM

```
sudo apt install git -y
```

- На все виртуальные машины склонировать репозиторий с GitHub ```
  ```
  git clone https://github.com/Lsir4ik/linux_basic_project.git
  ```
  Т.к. репозиторий содержит скрипты и файлы конфигурации для всего стенда, то необходимо использовать файлы в соответствии с назначением
  Для всех скриптов по пути ~/linux_basic_project/scripts должны быть права на выполнение

```
chmod +x $ИМЯ_ФАЙЛА
```

- Скопировать .dep-пакеты в домашнюю директорию в новую папку packages (`mkdir packages`) с ftp-сервера
  - nginx:
    - `nginx_1.24.0-2ubuntu7.15_amd64.deb`,
    - `prometheus-node-exporter_1.7.0-1ubuntu0.3_amd64.deb`,
    - `filebeat_8.17.1_amd64-224190-a5f894.deb`
  - backend1
    - `apache2_2.4.58-1ubuntu8.15_amd64.deb`
  - backend2
    - `apache2_2.4.58-1ubuntu8.15_amd64.deb`
  - source
    - `mysql-server-8.0_8.0.46-0ubuntu0.24.04.3_amd64.deb`,
    - `filebeat_8.17.1_amd64-224190-a5f894.deb`
  - replica
    - `mysql-server-8.0_8.0.46-0ubuntu0.24.04.3_amd64.deb`
  - monitoring
    - `prometheus_2.45.3+ds-2ubuntu0.3_amd64.deb`,
    - `grafana_12.3.3_21957728731_linux_amd64-224190-b33d09.deb`
  - elk
    - `elasticsearch_8.17.1_amd64-224lsel190-db972d.deb`,
    - `kibana_8.17.1_amd64-224190-42bf22.deb`,
    - `logstash_8.17.1_amd64-224190-40c12c.deb,
    - `default-jdk_2%3a1.21-75+exp1_amd64.deb`

## 2. Настройка сервера nginx

Запустить скрипты на nginx (192.168.0.107) из домашней директории:

```shell
./scripts/install_nginx.sh
./scripts/install_node_exporter.sh
./scripts/install_filebeat.sh
```

Скрипт `install_nginx.sh`:

- ставит Nginx 1.24.0 из .deb пакета;
- создаёт upstream `backend` на `192.168.0.244` и `192.168.0.203`;
- публикует `location /;
- включает и запускает Nginx.

Скрипт `install_node_exporter.sh`:

- ставит `prometheus-node-exporter` из .deb-пакета;
- отправляет метрики на сервер Prometheus на `192.168.0.243:9100`;
- включает и запускает `prometheus-node-exporter`.

Скрипт `install_filebeat.sh`:

- ставит Filebeat из .deb-пакета;
- копирует `configs/filebeat.yml` в `/etc/filebeat/filebeat.yml`;
- отправляет события в Logstash на `192.168.0.150:5400`;
- перезапускает Filebeat.

Проверка:

```shell
systemctl status nginx
systemctl status node_exporter
systemctl status filebeat
curl http://localhost
```

## 3. Настройка серверов backend1, backend2

Запустить скрипт на backend1 (192.168.0.244), backend2 (192.168.0.203) из домашней директории:

```shell
./scripts/install_apache.sh
```

Скрипт `install_apache.sh`:

- ставит Apache2 2.4.58 из .deb пакета;
- поднимает web-сервера на `192.168.0.244:8081` и `192.168.0.203:8082` соответственно;
- заменяет статические файлы стартовых страниц index.html для отслеживания работы балансировщика;
- включает и запускает Apache2.

Проверка:

```shell
systemctl status apache2
```

## 4. Настройка MySQL Source сервера

Запустить скрипт на source (192.168.0.148) из домашней директории:

```shell
./scripts/install_source.sh
```

Скрипт `install_master_v1.sh`:

- ставит `mysql-server-8.0`;
- настраивает `bind-address = 0.0.0.0`;
- задаёт `server-id = 1`;
- включает `gtid-mode = ON`;
- включает `enforce-gtid-consistency = ON`;
- включает `log-replica-updates = ON`;
- создаёт базу `my_app`;
- создаёт пользователей `app_user`, `repl`, `mysqld_exporter`;
- создаёт таблицу `users` и добавляет тестовые записи.
- ставит Filebeat из .deb-пакета;
- копирует `configs/filebeat.yml` в `/etc/filebeat/filebeat.yml`;
- отправляет события в Logstash на `192.168.0.150:5400`;
- перезапускает Filebeat.
  Проверка:

```shell
systemctl status mysql
mysql -u root -p -e "SHOW DATABASES;"
mysql -u root -p -e "SHOW MASTER STATUS;"
```

## 5. Настройка MySQL Replica сервера

Запустить скрипт на replica (192.168.0.169) из домашней директории:

```shell
./scripts/install_replica.sh
```

Скрипт `install_replica.sh`:

- ставит `mysql-server-8.0`;
- настраивает `server-id = 2`;
- включает `relay-log = relay-log-server`;
- включает `read-only = ON`;
- включает `gtid-mode = ON`;
- включает `enforce-gtid-consistency = ON`;
- включает `log-replica-updates = ON`;
- подключается к `master` по `CHANGE REPLICATION SOURCE TO`;
- использует `SOURCE_AUTO_POSITION = 1`;
- запускает `START REPLICA`;
- создаёт пользователя `backup_user` для резервного копирования.

Проверка:

```shell
systemctl status mysql
mysql -u root -p -e "SHOW REPLICA STATUS\G"
```

##### Бэкапы

Бэкапы базы данных выполняются на сервере `replica` скриптом:

```shell
./scripts/db_backup.sh
```

- Бэкап выполняется потаблично.
- Каждая таблица сохраняется в отдельный файл.
- Используется `--single-transaction`.
- Используется `--source-data=2`, поэтому координаты репликации сохраняются внутри дампа.
- Архивирование выполняется через `gzip`.

##### Структура хранения

```
/var/db-backup/mysql/YYYYMMDD_HHMMSS/
└── <database>/
    ├── table1_YYYYMMDD_HHMMSS.sql.gz
    ├── table2_YYYYMMDD_HHMMSS.sql.gz
    └── ...
```

##### Что попадает в бэкап

- Все пользовательские базы данных, кроме:
  - `information_schema`
  - `performance_schema`
- Все таблицы каждой базы.
- Триггеры, процедуры и события.

##### Восстановление

Пример восстановления одного файла:

```shell
gunzip < table.sql.gz | mysql -u root -p
```

После восстановления нужной базы из дампа можно использовать встроенный `CHANGE REPLICATION SOURCE TO`, если требуется пересоздать репликацию.

### Проверка

- Проверить наличие каталога бэкапа:
  ```shell
  ls /var/db-backup/
  ```
- Проверить наличие `.sql.gz` файлов.
- Проверить, что файлы не пустые.
- Периодически тестировать восстановление на отдельной тестовой ВМ.

## 6. Настройка мониторинга

Запустить скрипт на monitoring (192.168.0.243) из домашней директории:

```shell
./scripts/install_monintoring.sh
```

Скрипт `install_monitoring.sh`:

- ставит Prometheus из .deb пакета;
- копирует `configs/prometheus.yml` в `/etc/prometheus/prometheus.yml`;
- устанавливает Grafana из `.deb`-пакета;
- запускает `grafana-server`.

Проверка:

```shell
systemctl status prometheus
systemctl status grafana-server
curl http://localhost:9090
curl http://localhost:3000
```

## 7. Настройка ELK-стека

Запустить скрипт на elk (192.168.0.150) из домашней директории:

```shell
./scripts/install_elk.sh
```

Скрипт `install_elk.sh`:

- ставит JDK;
- устанавливает Elasticsearch, Kibana и Logstash из `.deb`-пакетов из домашней директории;
- копирует `configs/elasticsearch.yml`, `configs/kibana.yml`, `configs/logstash.yml`;
- задаёт JVM-параметры Elasticsearch;
- настраивает Elasticsearch на `http.host: 0.0.0.0` и отключает security/TLS;
- запускает Kibana на `0.0.0.0:5601`;
- настраивает Logstash input beats на `5400`;
- отправляет nginx-логи, mysql-логи в индекс `weblogs-*`.

Проверка:

```shell
systemctl status elasticsearch
systemctl status logstash
systemctl status kibana
curl http://localhost:9200
curl http://localhost:5601
```

## 8. Финальная проверка

- Открыть сайт через `nginx` (например, `http://192.168.0.107/`).
- Проверить, что запросы распределяются между `backen1` и `backen1`.
- Проверить состояние репликации MySQL.
- Убедиться в наличии метрик в Prometheus/Grafana.
- Убедиться в наличии логов Nginx, MySQL Source в Kibana.
