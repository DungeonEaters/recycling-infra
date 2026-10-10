#!/usr/bin/env bash
set -euo pipefail

sudo chown -R "$(id -u):$(id -g)" /workspaces/recycling-backend/.venv

python -m venv /workspaces/recycling-backend/.venv
/workspaces/recycling-backend/.venv/bin/pip install --quiet --upgrade pip
/workspaces/recycling-backend/.venv/bin/pip install --quiet -r /workspaces/recycling-backend/requirements.txt

echo "Ready. Application services run through Docker Compose; use the multi-root workspace for code."
