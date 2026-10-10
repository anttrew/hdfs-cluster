#!/usr/bin/env bash

set -e

SSH_KEY="$HOME/.ssh/team_internal"
NAMENODE="team-36-nn"
HADOOP_DIR="/opt/hadoop"

echo "Checking HDFS cluster..."

REPORT=$(ssh -i "$SSH_KEY" "team@$NAMENODE" \
  "${HADOOP_DIR}/bin/hdfs dfsadmin -report")

echo "$REPORT" | grep "Live datanodes (3)" >/dev/null

echo "  [OK] 3 live DataNodes"

ssh -i "$SSH_KEY" "team@$NAMENODE" \
  "echo 'HDFS healthcheck' > /tmp/hdfs-healthcheck.txt &&
   ${HADOOP_DIR}/bin/hdfs dfs -mkdir -p /user/team &&
   ${HADOOP_DIR}/bin/hdfs dfs -put -f /tmp/hdfs-healthcheck.txt /user/team/healthcheck.txt"

FSCK=$(ssh -i "$SSH_KEY" "team@$NAMENODE" \
  "${HADOOP_DIR}/bin/hdfs fsck /user/team/healthcheck.txt -files -blocks -locations")

echo "$FSCK" | grep "Status: HEALTHY" >/dev/null
echo "$FSCK" | grep "Live_repl=3" >/dev/null

echo "  [OK] HDFS filesystem is HEALTHY"
echo "  [OK] replication factor is 3"
echo
echo "All checks passed."
