#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source config/spark-env.sh

INPUT_PATH="/user/hive/warehouse/hw3.db/events"
OUTPUT_PATH="/user/team/hw4/events_summary"
JDBC_URL="jdbc:hive2://team-36-00:10000/default"

echo "Checking source data"

/opt/hadoop/bin/hdfs dfs -test -e "$INPUT_PATH" || {
    echo "[FAIL] source path does not exist: $INPUT_PATH"
    exit 1
}

echo "[OK] source data exists in HDFS"

echo
echo "Removing previous Spark output"

/opt/hadoop/bin/hdfs dfs -rm -r -f "$OUTPUT_PATH" 2>/dev/null || true

echo
echo "Running Spark application on YARN"

/opt/spark/bin/spark-submit \
    --master yarn \
    --deploy-mode client \
    --conf spark.executor.instances=2 \
    --conf spark.executor.memory=512m \
    --conf spark.executor.cores=1 \
    app/spark_events.py

echo
echo "Registering Spark output in Hive"

/opt/hive/bin/beeline \
    -u "$JDBC_URL" \
    -f sql/register-spark-table.sql

echo
echo "HW4 Spark pipeline finished."
