#!/usr/bin/env bash
# Linux/macOS/Android(Termux) setup. Usage: bash scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install -q -r requirements.txt
[ -f .env ] || { cp .env.example .env; echo "Created .env - fill in your values."; }
.venv/bin/python -m app init-db
.venv/bin/python -m app selftest
.venv/bin/python -m pytest
