#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
HADOOP_DIR="/opt/hadoop"

RESOURCE_MANAGER="team-36-00"

NODES=(
  "team-36-nn"
  "team-36-00"
  "team-36-01"
)

echo "Deploying YARN configuration..."

for node in "${NODES[@]}"; do
    echo "  -> $node"

    scp -i "$SSH_KEY" \
        config/yarn-site.xml \
        config/mapred-site.xml \
        "team@$node:${HADOOP_DIR}/etc/hadoop/"

    ssh -i "$SSH_KEY" "team@$node" \
        "sudo mkdir -p \
            /var/lib/hadoop-yarn/local \
            /var/log/hadoop-yarn/containers &&
         sudo chown -R team:team \
            /var/lib/hadoop-yarn \
            /var/log/hadoop-yarn"
done

echo
echo "Starting ResourceManager on $RESOURCE_MANAGER..."

ssh -i "$SSH_KEY" "team@$RESOURCE_MANAGER" \
    "jps | awk '{print \$2}' | grep -qx ResourceManager ||
     ${HADOOP_DIR}/bin/yarn --daemon start resourcemanager"

echo
echo "Starting NodeManagers..."

for node in "${NODES[@]}"; do
    echo "  -> $node"

    ssh -i "$SSH_KEY" "team@$node" \
        "jps | awk '{print \$2}' | grep -qx NodeManager ||
         ${HADOOP_DIR}/bin/yarn --daemon start nodemanager"
done

echo
echo "Starting JobHistoryServer on $RESOURCE_MANAGER..."

ssh -i "$SSH_KEY" "team@$RESOURCE_MANAGER" \
    "jps | awk '{print \$2}' | grep -qx JobHistoryServer ||
     ${HADOOP_DIR}/bin/mapred --daemon start historyserver"

echo
echo "YARN deployment finished."
