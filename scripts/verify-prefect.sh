#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Checking Prefect"
/usr/bin/test -x .venv/bin/python
.venv/bin/python -c "import prefect; print('Prefect', prefect.__version__)"

echo
echo "Checking Spark/YARN/Hive result"
./scripts/verify-spark.sh

echo
echo "Prefect workflow checks passed."
