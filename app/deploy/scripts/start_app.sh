#!/bin/bash
set -euo pipefail
systemctl daemon-reload
systemctl restart tomcat
systemctl restart httpd
systemctl enable tomcat httpd codedeploy-agent
