# Publish Checklist

この repository をポートフォリオとして公開する前の確認リストです。

## 公開前に確認するもの

- `terraform.tfvars` が Git 管理されていないこと
- `*.tfstate` と `*.tfstate.backup` が Git 管理されていないこと
- `.terraform/` が Git 管理されていないこと
- AWS access key, secret access key, session token が含まれていないこと
- RDS password や Secrets Manager の secret value が含まれていないこと
- 個人メールアドレスを公開してよいか確認すること
- AWS account ID を公開するか、`123456789012` などへマスクするか決めること
- 実在 domain を公開するか、`example.com` へ置き換えるか決めること
- CloudWatch Logs や terminal output の貼り付けに secret value が含まれていないこと

## 推奨する公開構成

```text
README.md
docs/
  architecture.md
  operations.md
  portfolio-case-study.md
  publish-checklist.md
  assets/
    architecture.png
    pipeline-succeeded.png
    application-screenshot.png
```

`docs/assets/` には、公開して問題ないスクリーンショットだけを置きます。AWS account ID、個人メールアドレス、secret ARN、RDS endpoint を写す場合はマスクしてください。

## README の冒頭例

```markdown
# AWS Learning Web

Terraform と AWS CodePipeline / CodeBuild / CodeDeploy を使い、AWS 上に商用環境を模した Web アプリケーション基盤を構築する学習プロジェクトです。

GitHub push を起点に、Terraform によるインフラ更新、Java/Tomcat アプリケーションの build、CodeDeploy による EC2 への配布までを自動化しています。

## Portfolio

- [Portfolio Case Study](docs/portfolio-case-study.md)
- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
```

## GitHub Pages で公開する場合

GitHub Pages 用に `docs/` を公開元にするか、別 repository を作って静的ページとして公開します。実行用 repository をそのまま公開する場合は、機密情報の除外を先に確認してください。

おすすめは次のどちらかです。

- 実装 repository: Terraform とアプリコードを公開
- Portfolio repository: 図、スクリーンショット、解説記事を公開

## 記事化する場合の構成案

```text
タイトル:
TerraformとCodePipelineでAWS三層Web環境を構築し、CodeDeployまで自動化した

構成:
1. 作ったもの
2. 全体アーキテクチャ
3. Terraform module 設計
4. CI/CD 設計
5. RDS と Secrets Manager
6. CodeDeploy hook
7. 動作確認
8. ハマった点と解決
9. 削除手順とコスト注意
10. 本番化するなら
```

## 採用・面談向けの説明文

```text
Terraform を使って AWS 上に三層 Web アプリケーション基盤を構築し、GitHub 連携の CodePipeline でインフラ変更とアプリケーションデプロイを自動化しました。ALB、Auto Scaling、RDS MySQL、Secrets Manager、Route 53、CloudWatch、SSM、CodeDeploy を組み合わせ、構築から動作確認、トラブルシュート、削除までを再現可能な IaC として整理しています。
```

## 公開後に見せると強いもの

- Architecture diagram
- Pipeline succeeded のスクリーンショット
- Application screenshot
- `curl /health` の `200 OK`
- CodeDeploy `Succeeded`
- RDS metadata `available`
- Session Manager から DB check / seed を実行した結果
- 失敗原因と修正 commit の対応表

