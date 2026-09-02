#!/bin/bash
set -euo pipefail
test -s /opt/aws-learning-web/revision/ROOT.war
install -o tomcat -g tomcat -m 0644 /opt/aws-learning-web/revision/ROOT.war /opt/tomcat/webapps/ROOT.war
chown -R tomcat:tomcat /opt/tomcat/webapps
