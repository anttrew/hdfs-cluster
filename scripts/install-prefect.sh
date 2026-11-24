#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! python3 -m venv --help >/dev/null 2>&1; then
    echo "Installing python3.12-venv"
    sudo apt update
    sudo apt install -y python3.12-venv
fi

rm -rf .venv
python3 -m venv .venv

.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install "prefect>=3,<4"

.venv/bin/python -c "import prefect; print('Prefect', prefect.__version__)"
