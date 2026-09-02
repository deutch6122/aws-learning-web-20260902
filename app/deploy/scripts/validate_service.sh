#!/bin/bash
set -euo pipefail
for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1/health >/dev/null && curl --fail --silent --show-error --max-time 5 http://127.0.0.1/ >/dev/null; then
    echo "Apache health and Tomcat application are ready"
    exit 0
  fi
  echo "Waiting for application ($attempt/30)"
  sleep 5
done
journalctl -u tomcat --no-pager -n 100 || true
exit 1
