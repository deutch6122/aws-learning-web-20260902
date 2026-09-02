#!/usr/bin/env python3
"""Create the messages table and insert idempotent sample data."""
import argparse
import json
import os
import boto3
import pymysql

ROWS = [
    ("Welcome to AWS Learning Site", "This message is loaded from Amazon RDS MySQL."),
    ("Infrastructure is connected", "Apache, Tomcat, EC2 Auto Scaling, RDS, CloudWatch, and SSM are working."),
]

def load_secret(arn: str, region: str) -> dict:
    value = boto3.client("secretsmanager", region_name=region).get_secret_value(SecretId=arn)["SecretString"]
    return json.loads(value)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret-arn", default=os.environ.get("DB_SECRET_ARN"))
    parser.add_argument("--region", default=os.environ.get("AWS_REGION", "ap-northeast-1"))
    args = parser.parse_args()
    if not args.secret_arn:
        raise SystemExit("Set DB_SECRET_ARN or pass --secret-arn")
    secret = load_secret(args.secret_arn, args.region)
    connection = pymysql.connect(host=secret["host"], port=int(secret["port"]), user=secret["username"], password=secret["password"], database=secret["dbname"], connect_timeout=10, autocommit=True)
    with connection:
        with connection.cursor() as cursor:
            cursor.execute("CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL UNIQUE, body TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")
            cursor.executemany("INSERT INTO messages (title, body) VALUES (%s, %s) ON DUPLICATE KEY UPDATE body=VALUES(body)", ROWS)
    print(f"Seed complete: {len(ROWS)} messages")

if __name__ == "__main__":
    main()
