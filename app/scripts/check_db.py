#!/usr/bin/env python3
"""Verify the RDS connection without printing credentials."""
import argparse
import json
import os
import boto3
import pymysql

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret-arn", default=os.environ.get("DB_SECRET_ARN"))
    parser.add_argument("--region", default=os.environ.get("AWS_REGION", "ap-northeast-1"))
    args = parser.parse_args()
    if not args.secret_arn:
        raise SystemExit("Set DB_SECRET_ARN or pass --secret-arn")
    secret = json.loads(boto3.client("secretsmanager", region_name=args.region).get_secret_value(SecretId=args.secret_arn)["SecretString"])
    connection = pymysql.connect(host=secret["host"], port=int(secret["port"]), user=secret["username"], password=secret["password"], database=secret["dbname"], connect_timeout=10)
    with connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT DATABASE(), VERSION()")
            database, version = cursor.fetchone()
    print(f"DB connection OK: database={database}, mysql_version={version}")

if __name__ == "__main__":
    main()
