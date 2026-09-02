#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

AWS_REGION="${aws_region}"
SECRET_ARN="${secret_arn}"
APP_VERSION="${app_version}"
TOMCAT_VERSION="10.1.34"

dnf update -y
dnf install -y httpd python3 python3-pip ruby wget tar gzip rsyslog amazon-cloudwatch-agent java-17-amazon-corretto-headless
pip3 install --no-cache-dir boto3 PyMySQL
systemctl enable --now rsyslog amazon-ssm-agent

# Apacheを入口にし、/healthだけはDBやTomcatに依存しない静的応答にする。
mkdir -p /var/www/html /opt/aws-learning-web /var/log/aws-learning-web
chown tomcat:tomcat /var/log/aws-learning-web 2>/dev/null || true
printf 'OK\n' > /var/www/html/health
cat >/etc/httpd/conf.d/learning-app.conf <<'APACHE'
ProxyPreserveHost On
ProxyPass /health !
Alias /health /var/www/html/health
<Location /health>
  Require all granted
</Location>
ProxyPass / http://127.0.0.1:8080/
ProxyPassReverse / http://127.0.0.1:8080/
APACHE

# 固定版をApache archiveから取得し、再現性を優先する。
useradd --system --home /opt/tomcat --shell /sbin/nologin tomcat || true
chown tomcat:tomcat /var/log/aws-learning-web
wget -q "https://archive.apache.org/dist/tomcat/tomcat-10/v$${TOMCAT_VERSION}/bin/apache-tomcat-$${TOMCAT_VERSION}.tar.gz" -O /tmp/tomcat.tar.gz
mkdir -p /opt/tomcat
tar xzf /tmp/tomcat.tar.gz --strip-components=1 -C /opt/tomcat
chown -R tomcat:tomcat /opt/tomcat

cat >/etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat
After=network.target
[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_PID=/run/tomcat/tomcat.pid
Environment=JAVA_OPTS=-Djava.awt.headless=true
EnvironmentFile=/etc/aws-learning-web.env
RuntimeDirectory=tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

cat >/etc/aws-learning-web.env <<EOF
AWS_REGION=$${AWS_REGION}
DB_SECRET_ARN=$${SECRET_ARN}
APP_VERSION=$${APP_VERSION}
CATALINA_OPTS="-Daws.region=$${AWS_REGION} -Ddb.secret.arn=$${SECRET_ARN} -Dapp.version=$${APP_VERSION}"
EOF
chown root:tomcat /etc/aws-learning-web.env
chmod 0640 /etc/aws-learning-web.env

# CodeDeploy Agent
cd /tmp
wget -q "https://aws-codedeploy-$${AWS_REGION}.s3.$${AWS_REGION}.amazonaws.com/latest/install" -O install-codedeploy
chmod +x install-codedeploy
./install-codedeploy auto

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {"metrics_collection_interval": 60, "run_as_user": "root"},
  "metrics": {
    "append_dimensions": {"AutoScalingGroupName": "\$${aws:AutoScalingGroupName}", "InstanceId": "\$${aws:InstanceId}"},
    "aggregation_dimensions": [["AutoScalingGroupName"]],
    "metrics_collected": {
      "mem": {"measurement": ["mem_used_percent"]},
      "disk": {"measurement": ["used_percent"], "resources": ["/"], "ignore_file_system_types": ["sysfs", "devtmpfs", "tmpfs"]}
    }
  },
  "logs": {"logs_collected": {"files": {"collect_list": [
    {"file_path": "/var/log/messages", "log_group_name": "/aws/ec2/${project_name}/messages${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/var/log/cloud-init-output.log", "log_group_name": "/aws/ec2/${project_name}/cloud-init${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/var/log/httpd/access_log", "log_group_name": "/aws/ec2/${project_name}/apache-access${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/var/log/httpd/error_log", "log_group_name": "/aws/ec2/${project_name}/apache-error${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/opt/tomcat/logs/catalina.out", "log_group_name": "/aws/ec2/${project_name}/tomcat${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/var/log/aws-learning-web/app.log", "log_group_name": "/aws/ec2/${project_name}/application${name_suffix_tag}", "log_stream_name": "{instance_id}"},
    {"file_path": "/var/log/aws/codedeploy-agent/codedeploy-agent.log", "log_group_name": "/aws/ec2/${project_name}/codedeploy${name_suffix_tag}", "log_stream_name": "{instance_id}"}
  ]}}}
}
EOF

systemctl daemon-reload
systemctl enable --now httpd tomcat codedeploy-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
