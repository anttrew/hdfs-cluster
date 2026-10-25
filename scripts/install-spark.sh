#!/usr/bin/env bash
set -euo pipefail

SPARK_VERSION="3.5.9"
SPARK_ARCHIVE="spark-${SPARK_VERSION}-bin-hadoop3.tgz"
SPARK_DIR="/opt/spark-${SPARK_VERSION}-bin-hadoop3"
SPARK_URL="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_ARCHIVE}"

if [ ! -x "${SPARK_DIR}/bin/spark-submit" ]; then
    echo "Downloading Spark ${SPARK_VERSION}..."

    wget -O "/tmp/${SPARK_ARCHIVE}" "$SPARK_URL"

    sudo tar -xzf "/tmp/${SPARK_ARCHIVE}" -C /opt

    rm -f "/tmp/${SPARK_ARCHIVE}"
else
    echo "Spark ${SPARK_VERSION} is already installed."
fi

sudo ln -sfn "$SPARK_DIR" /opt/spark

echo
/opt/spark/bin/spark-submit --version

echo
echo "Spark installation finished."
