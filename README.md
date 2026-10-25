# Hadoop cluster

Кластер из трёх внутренних узлов с HDFS, YARN, Hive и Spark.

```text
team-36-en   edge / client
team-36-nn   NameNode + DataNode + NodeManager
team-36-00   ResourceManager + DataNode + NodeManager + Hive
team-36-01   DataNode + NodeManager
```

## HDFS

HDFS работает с replication factor `3`.

Развертывание:

```bash
./scripts/deploy.sh
```

Проверка:

```bash
./scripts/verify.sh
```

## YARN

ResourceManager работает на `team-36-00`, NodeManager запущен на всех трёх узлах.

Развертывание:

```bash
./scripts/deploy-yarn.sh
```

Проверка:

```bash
./scripts/verify-yarn.sh
```

Состояние узлов:

```bash
/opt/hadoop/bin/yarn node -list
```

## Hive

Hive использует отдельный Metastore и PostgreSQL, поэтому поддерживает несколько одновременных клиентов.

HiveServer2:

```text
team-36-00:10000
```

Подключение:

```bash
beeline -u 'jdbc:hive2://team-36-00:10000/default'
```

Загрузка данных в партиционированную таблицу:

```bash
./scripts/load-hive-data.sh
```

Проверка:

```bash
./scripts/verify-hive.sh
```

Исходная таблица:

```text
hw3.events
```

Партиционирование:

```text
event_date=2026-10-22
event_date=2026-10-23
```

## Spark

Используется Apache Spark 3.5.9 под управлением YARN.

Установка:

```bash
./scripts/install-spark.sh
```

Запуск обработки:

```bash
./scripts/run-spark.sh
```

Spark:

1. читает `hw3.events` из HDFS;
2. преобразует типы и строки;
3. выполняет агрегацию;
4. сохраняет результат в Parquet;
5. разбивает результат по `event_date`;
6. регистрирует результат как Hive-таблицу.

Результат в HDFS:

```text
/user/team/hw4/events_summary
```

Hive-таблица:

```text
hw4.events_summary
```

Проверка:

```bash
./scripts/verify-spark.sh
```

## Проверенное состояние

```text
HDFS: 3 DataNode, replication factor 3
YARN: 3 NodeManager
Hive: partitioned tables доступны через Beeline
Spark: приложения выполняются под YARN
```
