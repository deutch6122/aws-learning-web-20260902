#!/bin/bash
set -euo pipefail
systemctl stop tomcat || true
install -d -m 0755 /opt/aws-learning-web/revision /opt/aws-learning-web/scripts
rm -f /opt/aws-learning-web/revision/ROOT.war
rm -rf /opt/tomcat/webapps/ROOT /opt/tomcat/webapps/ROOT.war
