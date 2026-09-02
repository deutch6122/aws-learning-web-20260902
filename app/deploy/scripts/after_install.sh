#!/bin/bash
set -euo pipefail
source /etc/aws-learning-web.env
export AWS_REGION DB_SECRET_ARN
python3 /opt/aws-learning-web/scripts/check_db.py
python3 /opt/aws-learning-web/scripts/seed_db.py
