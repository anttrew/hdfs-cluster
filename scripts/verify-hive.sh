#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
HIVE_HOST="team-36-00"
JDBC_URL="jdbc:hive2://team-36-00:10000/default"

echo "Checking Hive services..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" \
    "ss -ltn | grep -q ':9083 '"

echo "  [OK] Hive Metastore listens on 9083"

ssh -i "$SSH_KEY" "team@$HIVE_HOST" \
    "ss -ltn | grep -q ':10000 '"

echo "  [OK] HiveServer2 listens on 10000"

ssh -i "$SSH_KEY" "team@$HIVE_HOST" \
    "/opt/hive/bin/schematool -dbType postgres -info 2>&1 |
     grep -q 'Metastore schema version'"

echo "  [OK] PostgreSQL-backed Metastore schema exists"

echo
echo "Checking HiveServer2 connection..."

beeline --silent=true \
    -u "$JDBC_URL" \
    -e "SHOW DATABASES;" \
    >/tmp/hive-databases.out 2>&1

grep -q "default" /tmp/hive-databases.out

echo "  [OK] Beeline connects through HiveServer2"

echo
echo "Checking two simultaneous clients..."

beeline --silent=true \
    -u "$JDBC_URL" \
    -e "SELECT 1;" \
    >/tmp/hive-client-1.out 2>&1 &
PID1=$!

beeline --silent=true \
    -u "$JDBC_URL" \
    -e "SHOW DATABASES;" \
    >/tmp/hive-client-2.out 2>&1 &
PID2=$!

wait "$PID1"
wait "$PID2"

echo "  [OK] two HiveServer2 clients completed successfully"

echo
echo "Checking partitions..."

PARTITIONS=$(beeline \
    --silent=true \
    --showHeader=false \
    --outputformat=tsv2 \
    -u "$JDBC_URL" \
    -e "SHOW PARTITIONS hw3.events;" \
    2>/dev/null)

echo "$PARTITIONS"

echo "$PARTITIONS" | grep -q "event_date=2026-10-22"
echo "$PARTITIONS" | grep -q "event_date=2026-10-23"

echo "  [OK] both partitions exist"

echo
echo "Checking table data..."

ROWS=$(beeline \
    --silent=true \
    --showHeader=false \
    --outputformat=tsv2 \
    -u "$JDBC_URL" \
    -e "SELECT user_id, event, event_date FROM hw3.events;" \
    2>/dev/null)

echo "$ROWS"

ROW_COUNT=$(echo "$ROWS" | awk -F '\t' '
    $1 ~ /^[0-9]+$/ && NF >= 3 { n++ }
    END { print n+0 }
')

if [ "$ROW_COUNT" -ne 6 ]; then
    echo "[FAIL] expected 6 rows, got $ROW_COUNT"
    exit 1
fi

echo "  [OK] partitioned table contains 6 rows"

echo
echo "All Hive checks passed."
