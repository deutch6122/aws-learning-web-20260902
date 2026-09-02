# AWS Learning Web

Terraform、AWS CodePipeline、CodeBuild、CodeDeploy、EC2 Auto Scaling、ALB、RDS MySQL、Secrets Manager、Route 53 を組み合わせた、商用構成を意識した AWS インフラ構築ポートフォリオです。

## What I Built

- Terraform による AWS インフラのコード化
- GitHub 連携の CI/CD パイプライン
- CodeBuild による Terraform plan/apply と Java アプリケーションビルド
- CodeDeploy による EC2/Tomcat への自動デプロイ
- ALB、Auto Scaling、RDS MySQL、Secrets Manager を使った Web アプリ構成
- Route 53 による独自ドメイン公開
- SSM Session Manager による踏み台不要の運用確認

## Architecture

Browser → Route 53 → ALB → Apache → Tomcat → RDS MySQL

## Documents

- [Portfolio Case Study](./portfolio-case-study.md)
- [Architecture](./architecture.md)
- [Application and Database Design](./application-database-design.md)
- [Operations](./operations.md)
- [Publish Checklist](./publish-checklist.md)

## Result

CI/CD パイプラインからインフラ作成、アプリケーションデプロイ、DB初期データ投入、動作確認、最終的な削除まで一貫して実施しました。