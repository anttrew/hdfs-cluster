# Hadoop Cluster Deployment

Автоматизированное развёртывание HDFS + YARN-кластера на трёх внутренних нодах с edge-нодой для управления и публикации Web UI.

## Архитектура

```text
team-36-en
    |
    | SSH / deployment
    | nginx reverse proxy
    |
    +-- team-36-nn
    |      ├── NameNode
    |      ├── SecondaryNameNode
    |      ├── DataNode
    |      └── NodeManager
    |
    +-- team-36-00
    |      ├── DataNode
    |      ├── ResourceManager
    |      ├── NodeManager
    |      └── JobHistoryServer
    |
    +-- team-36-01
           ├── DataNode
           └── NodeManager
```

`team-36-en` используется как edge-нода, с которой запускаются скрипты развёртывания и проверки.

## Структура репозитория

```text
.
├── config/
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── mapred-site.xml
│   ├── yarn-site.xml
│   ├── workers
│   └── nginx/
│       ├── team36-cluster.conf
│       └── team36-proxy.conf
│
├── scripts/
│   ├── deploy.sh
│   ├── deploy-yarn.sh
│   ├── deploy-web.sh
│   ├── verify.sh
│   └── verify-yarn.sh
│
└── README.md
```

---

## HDFS

### Топология

В HDFS работают три DataNode:

- `team-36-nn`
- `team-36-00`
- `team-36-01`

NameNode и SecondaryNameNode расположены на `team-36-nn`.

Основные параметры:

```text
NameNode:            hdfs://team-36-nn:9000
Replication factor:  3
NameNode data:       /var/lib/hadoop-hdfs/namenode
DataNode data:       /var/lib/hadoop-hdfs/datanode
```

NameNode принимает RPC-соединения на всех сетевых интерфейсах, чтобы к нему могли подключаться остальные DataNode.

### Развёртывание HDFS

Запуск с `team-36-en`:

```bash
./scripts/deploy.sh
```

Скрипт:

- проверяет SSH-доступ до внутренних нод;
- устанавливает OpenJDK 17;
- устанавливает Hadoop 3.5.0, если он отсутствует;
- копирует конфигурацию HDFS;
- создаёт директории для хранения данных;
- форматирует новый NameNode только при первом запуске;
- запускает NameNode, SecondaryNameNode и DataNode.

Повторный запуск не форматирует уже инициализированный NameNode.

### Проверка HDFS

```bash
./scripts/verify.sh
```

Проверяется:

- наличие 3 live DataNode;
- возможность записи файла в HDFS;
- replication factor = 3;
- состояние файловой системы `HEALTHY`.

Ручная проверка с NameNode:

```bash
/opt/hadoop/bin/hdfs dfsadmin -report
```

Ожидается:

```text
Live datanodes (3)
```

Дополнительно:

```bash
/opt/hadoop/bin/hdfs fsck /user/team/hello.txt -files -blocks -locations
```

Ожидаемый результат содержит:

```text
replication=3
Live_repl=3
Status: HEALTHY
```

---

## YARN

### Топология

ResourceManager расположен на:

```text
team-36-00
```

NodeManager запущен на всех трёх нодах:

```text
team-36-nn
team-36-00
team-36-01
```

JobHistoryServer расположен на:

```text
team-36-00
```

Основные внутренние Web UI:

```text
ResourceManager:   team-36-00:8088
JobHistoryServer:  team-36-00:19888

NodeManager:
team-36-nn:8042
team-36-00:8042
team-36-01:8042
```

### Развёртывание YARN

Запуск:

```bash
./scripts/deploy-yarn.sh
```

Скрипт:

- копирует `yarn-site.xml` и `mapred-site.xml` на все ноды;
- создаёт локальные директории YARN;
- запускает ResourceManager;
- запускает NodeManager на трёх нодах;
- запускает JobHistoryServer.

---

## Публикация Web UI

Для публикации Web UI используется nginx на `team-36-en`.

Reverse proxy сопоставляет внешние порты с внутренними Hadoop/YARN Web UI:

```text
9440 -> NameNode
9441 -> SecondaryNameNode

9442 -> DataNode (team-36-nn)
9443 -> DataNode (team-36-00)
9444 -> DataNode (team-36-01)

9445 -> ResourceManager

9446 -> NodeManager (team-36-nn)
9447 -> NodeManager (team-36-00)
9448 -> NodeManager (team-36-01)

9449 -> JobHistoryServer
```

Web UI публикуются через HTTPS и защищены HTTP Basic Authentication.

TLS private key и файл с учётными данными в публичный репозиторий не добавляются.

### Развёртывание reverse proxy

```bash
WEB_PASSWORD='your-password' ./scripts/deploy-web.sh
```

При первом запуске скрипт:

- устанавливает nginx;
- создаёт self-signed TLS-сертификат;
- создаёт Basic Auth credentials;
- устанавливает конфигурацию reverse proxy;
- проверяет конфигурацию nginx;
- перезагружает nginx.

Имя пользователя по умолчанию:

```text
team36
```

Пароль передаётся через переменную окружения и не хранится в репозитории.

### Ограничение внешнего доступа

Edge-нода находится за NAT инфраструктуры курса.

Внешние правила NAT / firewall управляются администраторами инфраструктуры и не настраиваются на самой VM.

Поэтому nginx локально публикует интерфейсы на портах `9440-9449`, но доступ к этим портам из внешней сети зависит от правил инфраструктуры.

При необходимости Web UI можно открыть через SSH port forwarding через доступный SSH-порт edge-ноды.

Пример для ResourceManager:

```bash
ssh -L 9445:team-36-00:8088 team@171.22.73.124
```

После этого Web UI доступен локально:

```text
http://localhost:9445
```

---

## Проверка YARN и Web UI

Автоматическая проверка:

```bash
./scripts/verify-yarn.sh
```

Скрипт проверяет:

- что ResourceManager доступен;
- что зарегистрированы 3 NodeManager;
- что все NodeManager имеют состояние `RUNNING`;
- что JobHistoryServer работает;
- что внутренние Web UI отвечают;
- что nginx слушает порты `9440-9449`;
- что на опубликованных endpoint включён Basic Authentication.

Для рабочего кластера ожидается:

```text
[OK] 3 NodeManagers are RUNNING
[OK] ResourceManager is running
[OK] JobHistoryServer is running
[OK] Internal Hadoop/YARN web interfaces respond

All YARN and web proxy checks passed.
```

---

## SSH-доступ

Для подключения от edge-ноды к внутренним машинам используется:

```text
~/.ssh/team_internal
```

Приватные SSH-ключи, TLS-ключи и файлы аутентификации nginx не хранятся в репозитории.

---

## Проверенное состояние кластера

HDFS:

```text
Live datanodes: 3
Replication factor: 3
Missing blocks: 0
Corrupt blocks: 0
Status: HEALTHY
```

YARN:

```text
Total Nodes: 3
Node State: RUNNING
ResourceManager: running
JobHistoryServer: running
```

Reverse proxy:

```text
9440-9449 -> HTTP 401 Unauthorized without credentials
```
