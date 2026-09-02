#!/bin/bash
set -euo pipefail
source /etc/aws-learning-web.env
export AWS_REGION DB_SECRET_ARN

run_with_retry() {
  local description="$1"
  shift
  for attempt in $(seq 1 30); do
    if "$@"; then
      echo "$description succeeded"
      return 0
    fi
    echo "$description failed; retrying ($attempt/30)"
    sleep 10
  done
  echo "$description failed after retries"
  return 1
}

run_with_retry "DB connection check" python3 /opt/aws-learning-web/scripts/check_db.py
run_with_retry "DB seed" python3 /opt/aws-learning-web/scripts/seed_db.py
