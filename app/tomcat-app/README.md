# Tomcat application

Java 17 / Jakarta Servlet 6のWARです。1ページ構成のAWS学習教材を静的resourceとして配信し、`/api/status` のServletがEC2 metadata、RDS接続状態、学習用messageをJSONで返します。

`db.secret.arn` System Propertyから対象Secret ARNを受け取り、AWS SDKのEC2 Role認証でSecrets Managerを読みます。passwordやSecret valueはWARとAPI responseに含めません。

```bash
mvn clean package
```

生成物は `target/ROOT.war` です。教材の差し替えとデプロイは [Web教材差し替え・デプロイ手順書](../../docs/web-application-replacement-guide.md) を参照してください。
