#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends jq curl unzip shellcheck
python -m pip install --disable-pip-version-check 'uv==0.8.22'
python scripts/install-aws-skills.py --verify
bash .devcontainer/scripts/verify-environment.sh
printf '\nNext: bash scripts/set-learnerlab-credentials.sh (in your own terminal).\n'
