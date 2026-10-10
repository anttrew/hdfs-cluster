#!/usr/bin/env bash

set -e

SSH_KEY="$HOME/.ssh/team_internal"

NAMENODE="team-36-nn"

DATANODES=(
  "team-36-00"
  "team-36-01"
)

ALL_NODES=(
  "$NAMENODE"
  "${DATANODES[@]}"
)

HADOOP_VERSION="3.5.0"
HADOOP_DIR="/opt/hadoop"
JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"

check_ssh() {
  echo "Checking SSH connectivity..."

  for node in "${ALL_NODES[@]}"; do
    echo "  -> $node"

    ssh -i "$SSH_KEY" \
      -o BatchMode=yes \
      -o ConnectTimeout=5 \
      "team@$node" \
      "hostname"
  done
}

install_java() {
  echo "Installing Java on all nodes..."

  for node in "${ALL_NODES[@]}"; do
    echo "  -> $node"

    ssh -i "$SSH_KEY" \
      -o BatchMode=yes \
      "team@$node" \
      "sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
  done
}

install_hadoop() {
  echo "Installing Hadoop ${HADOOP_VERSION} on all nodes..."

  for node in "${ALL_NODES[@]}"; do
    echo "  -> $node"

    ssh -i "$SSH_KEY" \
      -o BatchMode=yes \
      "team@$node" \
      "if [ ! -x '${HADOOP_DIR}/bin/hadoop' ]; then
         cd /tmp &&
         wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz &&
         tar -xzf hadoop-${HADOOP_VERSION}.tar.gz &&
         sudo mkdir -p '${HADOOP_DIR}' &&
         sudo chown team:team '${HADOOP_DIR}' &&
         cp -a hadoop-${HADOOP_VERSION}/. '${HADOOP_DIR}/'
       else
         echo 'Hadoop already installed'
       fi"
  done
}

deploy_configs() {
  echo "Deploying Hadoop configs..."

  for node in "${ALL_NODES[@]}"; do
    echo "  -> $node"

    scp -i "$SSH_KEY" \
      config/core-site.xml \
      config/hdfs-site.xml \
      config/workers \
      "team@$node:${HADOOP_DIR}/etc/hadoop/"

    ssh -i "$SSH_KEY" \
      "team@$node" \
      "grep -q '^export JAVA_HOME=${JAVA_HOME_PATH}$' '${HADOOP_DIR}/etc/hadoop/hadoop-env.sh' || \
       echo 'export JAVA_HOME=${JAVA_HOME_PATH}' >> '${HADOOP_DIR}/etc/hadoop/hadoop-env.sh'"
  done
}

prepare_storage() {
  echo "Preparing HDFS storage directories..."

  for node in "${ALL_NODES[@]}"; do
    echo "  -> DataNode storage on $node"

    ssh -i "$SSH_KEY" "team@$node" \
      "sudo mkdir -p /var/lib/hadoop-hdfs/datanode &&
       sudo chown -R team:team /var/lib/hadoop-hdfs"
  done

  echo "  -> NameNode storage on $NAMENODE"

  ssh -i "$SSH_KEY" "team@$NAMENODE" \
    "sudo mkdir -p /var/lib/hadoop-hdfs/namenode &&
     sudo chown -R team:team /var/lib/hadoop-hdfs"
}


format_namenode() {
  echo "Checking NameNode initialization..."

  ssh -i "$SSH_KEY" "team@$NAMENODE" \
    "if [ ! -f /var/lib/hadoop-hdfs/namenode/current/VERSION ]; then
       echo 'Formatting new NameNode...'
       ${HADOOP_DIR}/bin/hdfs namenode -format -nonInteractive
     else
       echo 'NameNode already formatted, skipping'
     fi"
}


start_cluster() {
  echo "Starting HDFS cluster..."

  echo "  -> NameNode"
  ssh -i "$SSH_KEY" "team@$NAMENODE" \
    "pgrep -f 'org.apache.hadoop.hdfs.server.namenode.NameNode' >/dev/null ||
     ${HADOOP_DIR}/bin/hdfs --daemon start namenode"

  sleep 2

  for node in "${ALL_NODES[@]}"; do
    echo "  -> DataNode on $node"

    ssh -i "$SSH_KEY" "team@$node" \
      "pgrep -f 'org.apache.hadoop.hdfs.server.datanode.DataNode' >/dev/null ||
       ${HADOOP_DIR}/bin/hdfs --daemon start datanode"
  done

  echo "  -> SecondaryNameNode"
  ssh -i "$SSH_KEY" "team@$NAMENODE" \
    "pgrep -f 'org.apache.hadoop.hdfs.server.namenode.SecondaryNameNode' >/dev/null ||
     ${HADOOP_DIR}/bin/hdfs --daemon start secondarynamenode"
}

check_ssh
install_java
install_hadoop
deploy_configs
prepare_storage
format_namenode
start_cluster

echo
echo "HDFS deployment finished."
