#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
HIVE_HOST="team-36-00"

HIVE_VERSION="4.1.0"
HIVE_DIR="/opt/apache-hive-${HIVE_VERSION}-bin"
HIVE_LINK="/opt/hive"

if [ -z "${HIVE_METASTORE_PASSWORD:-}" ]; then
    echo "HIVE_METASTORE_PASSWORD is not set."
    echo "Run:"
    echo "  HIVE_METASTORE_PASSWORD='your-password' ./scripts/deploy-hive.sh"
    exit 1
fi

echo "Installing PostgreSQL and Hive dependencies..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    sudo apt-get update &&
    sudo apt-get install -y \
        postgresql \
        wget \
        libpostgresql-jdbc-java
"

echo "Configuring PostgreSQL metastore..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    sudo systemctl enable --now postgresql

    sudo -u postgres psql -tc \
      \"SELECT 1 FROM pg_roles WHERE rolname='hive'\" |
      grep -q 1 ||
      sudo -u postgres psql -c \
      \"CREATE USER hive WITH PASSWORD '${HIVE_METASTORE_PASSWORD}'\"

    sudo -u postgres psql -c \
      \"ALTER USER hive WITH PASSWORD '${HIVE_METASTORE_PASSWORD}'\"

    sudo -u postgres psql -tc \
      \"SELECT 1 FROM pg_database WHERE datname='metastore_db'\" |
      grep -q 1 ||
      sudo -u postgres createdb -O hive metastore_db
"

echo "Installing Hive ${HIVE_VERSION}..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    if [ ! -x '${HIVE_DIR}/bin/hive' ]; then
        cd /tmp

        wget -q \
          https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz

        sudo tar -xzf \
          apache-hive-${HIVE_VERSION}-bin.tar.gz \
          -C /opt
    fi

    sudo ln -sfn '${HIVE_DIR}' '${HIVE_LINK}'

    sudo cp /usr/share/java/postgresql.jar \
        '${HIVE_LINK}/lib/postgresql.jar'
"

echo "Deploying hive-site.xml..."

sed \
  "s#__HIVE_METASTORE_PASSWORD__#${HIVE_METASTORE_PASSWORD}#g" \
  config/hive/hive-site.xml.template \
  >/tmp/hive-site.xml

scp -i "$SSH_KEY" \
    /tmp/hive-site.xml \
    "team@$HIVE_HOST:/tmp/hive-site.xml"

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    sudo cp /tmp/hive-site.xml '${HIVE_LINK}/conf/hive-site.xml'
    sudo chown root:root '${HIVE_LINK}/conf/hive-site.xml'
"

rm -f /tmp/hive-site.xml

echo "Preparing HDFS warehouse..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    /opt/hadoop/bin/hdfs dfs -mkdir -p \
        /user/hive/warehouse \
        /user/hive/tmp

    /opt/hadoop/bin/hdfs dfs -chmod 1777 \
        /user/hive/warehouse \
        /user/hive/tmp
"

echo "Initializing Metastore schema if necessary..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    /opt/hive/bin/schematool \
        -dbType postgres \
        -info >/dev/null 2>&1 ||
    /opt/hive/bin/schematool \
        -dbType postgres \
        -initSchema
"

echo "Starting Hive Metastore..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    pgrep -f 'org.apache.hadoop.hive.metastore.HiveMetaStore' >/dev/null ||
    nohup /opt/hive/bin/hive --service metastore \
        >/tmp/hive-metastore.log 2>&1 &
"

sleep 5

echo "Starting HiveServer2..."

ssh -i "$SSH_KEY" "team@$HIVE_HOST" "
    pgrep -f 'org.apache.hive.service.server.HiveServer2' >/dev/null ||
    nohup /opt/hive/bin/hiveserver2 \
        >/tmp/hiveserver2.log 2>&1 &
"

echo
echo "Hive deployment finished."
