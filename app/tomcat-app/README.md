# Tomcat application

Java 17 / Jakarta Servlet 6の小さなWARです。`db.secret.arn` System Propertyから対象Secret ARNを受け取り、AWS SDKのEC2 Role認証でSecrets Managerを読みます。パスワードはWARに含みません。

```bash
mvn clean package
```
