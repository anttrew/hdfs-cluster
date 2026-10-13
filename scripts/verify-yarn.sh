#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
RM="team-36-00"
HADOOP_DIR="/opt/hadoop"

echo "Checking YARN cluster..."

REPORT=$(ssh -i "$SSH_KEY" "team@$RM" \
    "${HADOOP_DIR}/bin/yarn node -list")

echo "$REPORT"

echo "$REPORT" | grep -q "Total Nodes:3"

RUNNING=$(echo "$REPORT" | grep -c "RUNNING")

if [ "$RUNNING" -ne 3 ]; then
    echo "[FAIL] Expected 3 RUNNING NodeManagers, got $RUNNING"
    exit 1
fi

echo
echo "[OK] 3 NodeManagers are RUNNING"

echo
echo "Checking ResourceManager..."

ssh -i "$SSH_KEY" "team@$RM" \
    "jps | awk '{print \$2}' | grep -qx ResourceManager"

echo "[OK] ResourceManager is running"

echo
echo "Checking JobHistoryServer..."

ssh -i "$SSH_KEY" "team@$RM" \
    "jps | awk '{print \$2}' | grep -qx JobHistoryServer"

echo "[OK] JobHistoryServer is running"

echo
echo "Checking internal web interfaces..."

URLS=(
    "http://team-36-nn:9870"
    "http://team-36-nn:9868"
    "http://team-36-nn:9864"
    "http://team-36-00:9864"
    "http://team-36-01:9864"
    "http://team-36-00:8088"
    "http://team-36-nn:8042"
    "http://team-36-00:8042"
    "http://team-36-01:8042"
    "http://team-36-00:19888"
)

for url in "${URLS[@]}"; do
    echo "  -> $url"
    curl -sSI --connect-timeout 5 "$url" >/dev/null
done

echo "[OK] Internal Hadoop/YARN web interfaces respond"

echo
echo "Checking nginx reverse proxy..."

for port in {9440..9449}; do
    CODE=$(curl -ks \
        -o /dev/null \
        -w '%{http_code}' \
        --connect-timeout 5 \
        "https://127.0.0.1:$port")

    if [ "$CODE" != "401" ]; then
        echo "[FAIL] nginx port $port returned HTTP $CODE"
        exit 1
    fi

    echo "  [OK] localhost:$port -> HTTP 401 (basic auth enabled)"
done

echo
echo "All YARN and web proxy checks passed."
