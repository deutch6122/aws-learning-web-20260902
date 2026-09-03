# AWS Learning Web 20260902

Terraform、CodePipeline、CodeBuild、CodeDeployを使い、AWS上に商用環境風の小規模Webシステムを構築する学習プロジェクトです。初回だけローカルから `bootstrap` を適用し、以後はGitHub pushを起点にインフラ更新とアプリ配布をAWS側で行います。

## 全体構成

```text
Internet / Route 53 app.filanza-aws.com
                 |
      Internet-facing ALB (Public x 2AZ)
                 |
 Apache -> Tomcat / Auto Scaling Group (Private App x 2AZ)
                 |
       RDS MySQL (Private DB x 2AZ subnet group, Single-AZ default)

EC2 -> Secrets Manager / CloudWatch / SSM / CodeDeploy
Alarm -> SNS Email; SNS -> AWS Chatbot or User Notifications -> Slack (manual connection)
```

詳細は [docs/architecture.md](docs/architecture.md)、[docs/application-database-design.md](docs/application-database-design.md)、[docs/operations.md](docs/operations.md) を参照してください。AP–DB詳細設計には、接続経路、Secret/IAM認証、Web参照、DB初期化、障害時の挙動をまとめています。教材画面の変更方法は [docs/web-application-replacement-guide.md](docs/web-application-replacement-guide.md) にまとめています。

ポートフォリオ公開用の叩き台は [docs/portfolio-case-study.md](docs/portfolio-case-study.md)、公開前チェックは [docs/publish-checklist.md](docs/publish-checklist.md) を参照してください。

## CI/CDフロー

```text
GitHub main push
  -> CodeConnections Source
  -> Terraform fmt / validate / plan
  -> Manual Approval (optional, default off)
  -> Terraform apply
  -> ASG / ALB target / SSM ready wait
  -> Maven WAR + AppSpec package
  -> CodeDeploy in-place deployment
  -> Apache/Tomcat restart and health validation
```

TerraformはVPC、RDS、ALBなどのインフラを作り、CodeDeployはEC2上のWAR更新だけを担当します。CodeDeployでインフラは作成しません。Plan stageの `tfplan.txt` はartifactに残します。Apply stageは、承認後のSourceに対してstateを再読込して新しいplanを作る `terraform apply -auto-approve` 方式です。PlanとApplyの厳密な同一性が必要な本番環境では、保存planの署名・同一コミット確認を追加してください。

## ディレクトリ

- `bootstrap`: state/artifact S3、DynamoDB補助ロック、CodePipeline/Build/Deploy、IAM
- `infra`: 実行環境のroot module
- `infra/modules/network`: VPC、6 subnet、IGW、NAT、optional endpoints
- `infra/modules/security`: ALB/App/DB Security Group
- `infra/modules/database`: encrypted RDS MySQL、接続Secret
- `infra/modules/loadbalancer`: ALB、Target Group、HTTP/optional HTTPS、Route 53 Alias
- `infra/modules/compute`: Launch Template、ASG、EC2 Role/Profile
- `infra/modules/monitoring`: Log Groups、metric filters、Alarms、SNS
- `infra/modules/operations`: Patch Baseline、Maintenance Window
- `app`: Tomcat WAR、DB scripts、CodeDeploy hooks
- `user_data`: Amazon Linux 2023初期設定
- `buildspecs`: CodeBuildの4 buildspec

## 作成される主なAWSリソース

VPC、Public/App/DB subnet各2、IGW、NAT Gateway 1、route tables、任意のinterface/S3 endpoints、Security Groups、ALB/listeners/Target Group、Launch Template/ASG/EC2 Role、RDS MySQL/DB subnet group/Secrets Manager、CloudWatch Logs/Alarms/metric filters、SNS、SSM Patch Baseline/Maintenance Window、Route 53 A Alias、state/artifact S3、DynamoDB lock table、CodePipeline、CodeBuild 4 project、CodeDeploy application/deployment group、および各IAM Roleです。

## 命名ルール

`Name` タグは可能な限り `_20260902`、物理名はサービス制約に応じて `-20260902` を使います。例: `Name=aws-learning-web-alb_20260902`、ALB物理名 `aws-learning-web-alb-20260902`。S3 bucketは全世界で一意にするためアカウントIDも末尾に付加します。タグは `Project`、`Environment`、`Owner=self`、`ManagedBy=terraform` をproviderのdefault tagsで付けます。

## 重要な前提と注意

- 指定どおり `20.0.0.0/16` を使いますが、これはRFC1918 private addressではありません。経路競合や意図しないルーティングの恐れがあるため、本番では通常 `10.0.0.0/16` 等を推奨します。
- `simple-blog.filanza-aws.com` と既存ACM検証CNAMEはTerraform管理対象に含めておらず、変更・削除しません。新規の `app.filanza-aws.com` A Aliasだけを作ります。
- EC2にSSH/22は開けません。Session Managerを使います。
- RDSは非公開・暗号化です。passwordはコード/User Dataにありません。Terraformがランダム生成しSecrets Managerへ保存するため、stateも機密情報として厳重に保護してください。
- NATを無効化しendpointsだけを有効にしても、OS package/Tomcat取得先へのインターネット経路がなく初回User Dataは完了しません。完全NATレス化にはAMI bakeまたはprivate artifact mirrorが必要です。
- ALB用ACM証明書はALBと同じ `ap-northeast-1` が必要です。CloudFront用 `us-east-1` 証明書は使用できません。

## 前提条件

1. AWS CLI v2、Terraform 1.10以上、Gitを用意する。
2. `aws sts get-caller-identity` が対象アカウントを返すよう認証する。Access Keyをリポジトリへ保存しない。
3. GitHub repositoryを作り、このディレクトリ内容をrepository rootへ置く。
4. AWS Developer Tools > Settings > ConnectionsでGitHub接続を作成し、GitHub側で承認して `AVAILABLE` にする。ARNは `ap-northeast-1` のものを使う。

## 初回bootstrap

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# github_owner, github_repo, codestar_connection_arn を編集
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

接続ARN、owner、repoが空のままではSource stageを作れません。作成されたstate bucket名を確認します。bootstrap stateも移行する場合は `backend.tf.example` を `backend.tf` として実値に直し、`terraform init -migrate-state` を実行します。

`infra/backend.tf` はbucket名を固定記載せず、CodeBuildが `TF_STATE_BUCKET` から `-backend-config=bucket=...` を渡します。ローカルでinfraを確認するときも同じ指定が必要です。

Pipelineで既定値以外を使う場合は `infra/pipeline.auto.tfvars.example` を `infra/pipeline.auto.tfvars` にコピーし、秘密情報を含めずにcommitします。`terraform.tfvars` はlocal確認用としてgitignoreされるため、CodeBuildには渡りません。`alarm_email`、`acm_certificate_arn`、NAT/endpoints、RDS設定などをapply前にここで確認してください。

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform fmt -recursive
terraform init -backend-config="bucket=BOOTSTRAP_OUTPUT_BUCKET"
terraform validate
terraform plan
```

## GitHub pushとPipeline

```bash
git add .
git commit -m "Update infrastructure and application"
git push origin main
aws codepipeline get-pipeline-state --name aws-learning-web-pipeline-20260902
```

Planの標準出力はCodeBuild logs、`tfplan.txt` はPlan artifactで確認できます。ApplyはCloudWatch Logsのapply project、CodeDeployはDeployments画面または次で確認します。

```bash
aws deploy list-deployments --application-name aws-learning-web-app-20260902 --deployment-group-name aws-learning-web-dg-20260902
aws deploy get-deployment --deployment-id d-XXXXXXXXX
```

`enable_manual_approval=true` は本番風の運用に推奨です。変更するとPipeline自体のbootstrap再適用が必要です。

## Web / Route 53 / HTTPS

```bash
aws elbv2 describe-load-balancers --names aws-learning-web-alb-20260902 --query 'LoadBalancers[0].DNSName' --output text
curl http://ALB_DNS/health
curl http://app.filanza-aws.com/health
aws route53 list-resource-record-sets --hosted-zone-id Z10320622XUBBC9Y04KQI --query "ResourceRecordSets[?Name=='app.filanza-aws.com.']"
```

HTTPS化は `infra/terraform.tfvars` の `acm_certificate_arn` にap-northeast-1の証明書ARNを設定してpushします。HTTPS listenerが作られ、HTTPは443へredirectされます。レコードを作らない場合は `create_route53_record=false` にします。

## Secret / RDS / 初期データ

Secret値を画面やログへ不用意に表示しないでください。metadataだけなら次で確認できます。

```bash
aws secretsmanager describe-secret --secret-id 'aws-learning-web/database_20260902'
aws rds describe-db-instances --db-instance-identifier aws-learning-web-rds-20260902
```

CodeDeployのAfterInstallが `check_db.py` とidempotentな `seed_db.py` を実行します。手動時はSession ManagerでEC2へ入り、systemdの設定からSecret ARNを確認して環境変数へ設定し、次を実行します。

```bash
python3 /opt/aws-learning-web/scripts/check_db.py
python3 /opt/aws-learning-web/scripts/seed_db.py
```

## Logs / Alarms / notifications

Log Groupsは `/aws/ec2/aws-learning-web/*_20260902`、retentionは既定7日です。messages、cloud-init、Apache access/error、Tomcat、application、CodeDeployを収集します。ALB/Target、EC2/ASG、CWAgent memory/disk、RDS、ログキーワードのalarmsをSNSへ通知します。

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/aws-learning-web/
aws cloudwatch describe-alarms --alarm-name-prefix aws-learning-web-
aws sns list-subscriptions-by-topic --topic-arn SNS_TOPIC_ARN
```

`alarm_email` が空でなければ確認メールが届きます。リンクを承認するまで通知されません。SlackはSNSまでTerraformで作成済みです。Amazon Q Developer in chat applications（旧AWS Chatbot）またはAWS User NotificationsでSlack Workspaceを手動承認し、このSNS topicを通知元へ指定してください。Workspace OAuthは無理にTerraform化していません。

## SSM / Patch Manager

```bash
aws ssm describe-instance-information
aws ssm start-session --target i-XXXXXXXX
aws ssm describe-maintenance-windows --filters Key=Name,Values=aws-learning-web-maintenance_20260902
aws ssm describe-maintenance-window-executions --window-id mw-XXXXXXXX
aws ssm describe-instance-patch-states --instance-ids i-XXXXXXXX
```

第1水曜11:00、`Asia/Tokyo`、`AWS-RunPatchBaseline`、Install、RebootIfNeededです。Maintenance Windowは対象EC2の `PatchGroup=app_20260902` tagを使います。手動検証時はPatch Managerの「Patch now」または `AWS-RunPatchBaseline` をRun Commandで実行します。

## CodeDeploy Agent

```bash
sudo systemctl status codedeploy-agent
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo tail -n 200 /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log
```

失敗時はagent、AppSpec hook、Tomcat journal、RDS接続、EC2のartifact bucket権限、DeployGroup tagを順に確認します。

## コスト

NAT Gatewayは時間・処理量課金があり、学習環境では主要コストになり得ます。RDSは起動時間とstorage/backup、ALBは時間とLCU、CodeBuildはbuild分、S3は保存・request、CloudWatchはlogs ingest/storage・custom metrics/alarms、CodePipeline/CodeDeployは最新料金体系を利用前に確認してください。VPC interface endpointsもAZ/時間課金です。停止だけではNAT、ALB、RDS等の課金は止まりません。

## 削除

Route 53 Aliasと実行環境を先に消し、CI/CDとstateを最後に消します。S3 versioning済みbucketは `force_destroy_buckets=true` の学習用既定で中身も削除されます。必要なstate/artifactを事前backupしてください。

```bash
cd infra
terraform init -backend-config="bucket=BOOTSTRAP_OUTPUT_BUCKET"
terraform destroy
cd ../bootstrap
terraform destroy
```

Deletion protectionをtrueにした場合はfalseへ戻してapplyしてからdestroyします。SNS購読、手動Slack設定、CodeConnectionsはbootstrap外のため必要に応じて手動削除します。

## よくあるエラー

- Source失敗: Connectionが `AVAILABLE`、owner/repo/branchとGitHub App権限が正しいか確認。
- `AccessDenied`: CodeBuild role policyと新規サービス権限を確認。本構成は学習用の広いaction群ですが、AWS Organizations SCP等も影響する。
- ALB unhealthy: `/var/log/cloud-init-output.log`、Apache、SG、`curl localhost/health` を確認。
- SSM offline: NAT/endpoints、EC2 Role、SSM Agent、DNSを確認。
- CodeDeployにtargetなし: ASG instanceへ `DeployGroup=app_20260902` が伝播しているか確認。
- DB timeout: App SG -> DB SG 3306、DB available、Secret hostを確認。
- Route 53競合: `app.filanza-aws.com` が既に存在する場合はimport/削除判断を行い、既存 `simple-blog` やCNAMEには触れない。
- Terraform lock: 進行中buildがないことを確認してからlock解除を検討し、stateを直接編集しない。

## 本番化の改善案

RFC1918 CIDR、NAT GatewayのAZ冗長化、RDS Multi-AZ/deletion protection/final snapshot、WAF、ALB access logs、ACM自動検証、KMS customer-managed keys、Secrets rotation、AMI baking、Auto Scaling policy、blue/green、canary、Plan artifactの厳密適用、Pipeline分離、OIDC/short-lived credentials、IAM action/resourceのモジュール別Role分離、central logs/SIEM、AWS Backup、Config/Security Hub/GuardDuty、VPC Flow Logs、private egress firewallを検討してください。特にTerraform Apply Roleは本構成では学習用に広く、実運用ではnetwork/database/IAM等を別pipeline/roleへ分割し、IAM作成とPassRole対象を限定すべきです。
