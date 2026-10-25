#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source config/spark-env.sh

JDBC_URL="jdbc:hive2://team-36-00:10000/default"
OUTPUT_PATH="/user/team/hw4/events_summary"

echo "Checking Spark"

/opt/spark/bin/spark-submit --version 2>&1 | grep -q "version 3.5.9"
echo "[OK] Spark 3.5.9 is installed"

echo
echo "Checking YARN"

NODES=$(/opt/hadoop/bin/yarn node -list 2>&1)

echo "$NODES" | grep -q "Total Nodes:3"
echo "[OK] YARN has 3 registered NodeManagers"

echo
echo "Checking Spark output in HDFS"

/opt/hadoop/bin/hdfs dfs -test -e "$OUTPUT_PATH"
echo "[OK] Spark output exists in HDFS"

/opt/hadoop/bin/hdfs dfs -ls "$OUTPUT_PATH"

echo
echo "Checking physical partitions"

HDFS_PARTITIONS=$(
    /opt/hadoop/bin/hdfs dfs -ls "$OUTPUT_PATH" |
    grep 'event_date=' || true
)

echo "$HDFS_PARTITIONS"

echo "$HDFS_PARTITIONS" | grep -q "event_date=2026-10-22"
echo "$HDFS_PARTITIONS" | grep -q "event_date=2026-10-23"

echo "[OK] output is partitioned by event_date"

echo
echo "Checking Hive table"

PARTITIONS=$(
    /opt/hive/bin/beeline \
        --silent=true \
        --showHeader=false \
        --outputformat=tsv2 \
        -u "$JDBC_URL" \
        -e "SHOW PARTITIONS hw4.events_summary;" \
        2>/dev/null
)

echo "$PARTITIONS"

echo "$PARTITIONS" | grep -q "event_date=2026-10-22"
echo "$PARTITIONS" | grep -q "event_date=2026-10-23"

echo "[OK] Hive sees both partitions"

echo
echo "Reading Spark result with Hive client"

/opt/hive/bin/beeline \
    --silent=true \
    -u "$JDBC_URL" \
    -e "SELECT * FROM hw4.events_summary;"

echo
echo "All Spark/Hive checks passed."
