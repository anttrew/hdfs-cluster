#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
HIVE_HOST="team-36-00"
HADOOP="/opt/hadoop/bin/hdfs"
JDBC_URL="jdbc:hive2://team-36-00:10000/default"

echo "Uploading sample data to HDFS..."

scp -i "$SSH_KEY" \
    data/hive/events_2026-10-22.csv \
    data/hive/events_2026-10-23.csv \
    "team@$HIVE_HOST:/tmp/"

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    $HADOOP dfs -mkdir -p /tmp/hive-hw3
    $HADOOP dfs -rm -f /tmp/hive-hw3/events_2026-10-22.csv 2>/dev/null || true
    $HADOOP dfs -rm -f /tmp/hive-hw3/events_2026-10-23.csv 2>/dev/null || true

    $HADOOP dfs -put /tmp/events_2026-10-22.csv /tmp/hive-hw3/
    $HADOOP dfs -put /tmp/events_2026-10-23.csv /tmp/hive-hw3/
"

echo "Creating partitioned Hive table and loading data..."

beeline \
    -u "$JDBC_URL" \
    -f sql/load-partitioned-table.sql

echo
echo "Hive partitioned data load finished."
