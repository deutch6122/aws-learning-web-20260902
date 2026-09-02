# Operations

## 日常確認

CodePipelineの最新実行、ALB target health、ASG desired/in-service、RDS status、CloudWatch alarms、SSM managed node、直近Maintenance Windowを確認します。通常の変更はlocal edit、commit、pushだけです。Production相当ではmanual approvalを有効にし、Plan artifactと変更ticketを照合します。

## Deploy / rollback

push後、SourceからDeployまで成功を確認します。アプリだけ戻す場合は正常だったGit commitをrevertしてpushします。CodeDeployはdeployment failure時に自動rollbackを有効化しています。インフラはstateとGit履歴を正とし、consoleで場当たり変更しません。緊急時も修正commitを作りPipelineを通します。

## Logsとalarm対応

CloudWatch Logs Insightsでinstance ID、時刻、`ERROR|Exception|OutOfMemory|Failed` を絞ります。ALB 5xxはALB/Target別、response timeはTomcat/RDS、unhealthyはApache/cloud-init/SGを確認します。memory/diskはSession Managerからprocess/filesystem、RDSはCPU/storage/memory/connections/latencyとslow query logを確認します。復旧後はalarmがOKへ戻ることを確認します。

## RDS / Secret

RDSへpublic接続しません。EC2へSession Manager接続し `/opt/aws-learning-web/scripts/check_db.py` を使います。Secret値をshell historyやticketへ貼らないでください。手動rotationはアプリとRDSのpassword整合を崩すため、Terraform外で一方だけ変更しません。本番ではSecrets Manager rotation Lambda/RDS managed master passwordを設計します。

## SSM / patch

Session ManagerはEC2 consoleまたは `aws ssm start-session --target ...` を使います。Patch Managerでbaseline association、target tag、execution history、instance patch stateを確認します。再起動を伴うため、desired=1の学習環境では停止時間が生じ得ます。本番ではASG rolling replacement、複数instance、maintenance coordinationを設計します。

## 障害切り分け

- CodePipeline: Source connection、artifact、stage transition/approvalを確認。
- CodeBuild: project CloudWatch log、role AccessDenied、Terraform init/state lock、provider errorを確認。
- CodeDeploy: target tag、agent service/log、artifact S3 permission、各hook log、Tomcat ownershipを確認。
- ALB: listener、SG、Target Group matcher `/health=200`、Apache statusを確認。
- DB: RDS status、3306 SG reference、Secret JSON、DNS、connection countを確認。

## Terraform state

infra stateはversioning/encryption/public-block済みS3とS3 native lockfileを使います。DynamoDB tableも互換・学習目的でbootstrapが作りますが、現在のbackendは `use_lockfile=true` です。同時applyは禁止し、force-unlockは実行中jobがないと確認してから行います。stateにはRDS passwordが含まれるため、bucket/IAMを機密データとして扱います。

## 削除

まずRoute 53を含むinfraをdestroyし、最後にbootstrapをdestroyします。RDS deletion protection、S3 backup要否、SNS/Slack/Connectionのbootstrap外設定を確認します。正確なコマンドとコスト停止条件はroot READMEを参照してください。
