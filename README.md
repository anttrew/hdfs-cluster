# HDFS Cluster Deployment

HDFS-кластер из трёх DataNode с автоматизированным развёртыванием.

## Схема кластера

```text
team-36-en
    |
    | SSH
    |
    +-- team-36-nn
    |      ├── NameNode
    |      ├── SecondaryNameNode
    |      └── DataNode
    |
    +-- team-36-00
    |      └── DataNode
    |
    +-- team-36-01
           └── DataNode
```

`team-36-en` используется как edge-нода, с которой запускаются скрипты развёртывания.

В итоге в HDFS работают три DataNode:

- `team-36-nn`
- `team-36-00`
- `team-36-01`

## Структура репозитория

```text
.
├── config/
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   └── workers
├── scripts/
│   ├── deploy.sh
│   └── verify.sh
└── README.md
```

## Развёртывание

Скрипт запускается с `team-36-en`.

Для доступа к внутренним нодам используется ключ:

```text
~/.ssh/team_internal
```

Запуск:

```bash
./scripts/deploy.sh
```

Скрипт:

- проверяет SSH-доступ до нод;
- устанавливает OpenJDK 17;
- устанавливает Hadoop 3.5.0, если его ещё нет;
- копирует конфиги Hadoop;
- создаёт директории для NameNode и DataNode;
- форматирует NameNode при первом запуске;
- запускает NameNode, SecondaryNameNode и DataNode.

Повторный запуск не форматирует уже инициализированный NameNode.

## Конфигурация

Основные параметры:

```text
NameNode:            hdfs://team-36-nn:9000
Replication factor:  3
NameNode data:       /var/lib/hadoop-hdfs/namenode
DataNode data:       /var/lib/hadoop-hdfs/datanode
```

NameNode принимает RPC-соединения на всех интерфейсах, чтобы к нему могли подключаться остальные DataNode.

## Проверка

Для автоматической проверки:

```bash
./scripts/verify.sh
```

Скрипт проверяет:

- что NameNode видит 3 live DataNode;
- что файл можно записать в HDFS;
- что блок имеет 3 реплики;
- что `fsck` возвращает `HEALTHY`.

Также можно проверить состояние вручную:

```bash
hdfs dfsadmin -report
```

Ожидается:

```text
Live datanodes (3)
```

Пример проверки файла:

```bash
hdfs fsck /user/team/hello.txt -files -blocks -locations
```

Для рабочего кластера вывод содержит:

```text
replication=3
Live_repl=3
Status: HEALTHY
```
