# Architecture

## 論理・ネットワーク構成

```text
Route 53 public hosted zone (existing)
  app.filanza-aws.com A Alias
       |
Internet Gateway -- Public subnet A/B -- ALB :80 (:443 optional)
                                      |
                    Private App subnet A/B -- ASG desired=1
                                      |      Apache :80 -> Tomcat :8080
             NAT Gateway or optional AWS endpoints
                                      |
                    Private DB subnet A/B -- encrypted RDS MySQL :3306
```

Public/App/DB subnetは `cidrsubnet(20.0.0.0/16, 8, index)` で分離します。ALB SGはinternetから80、証明書指定時だけ443を許可します。App SGはALB SGから80/8080、DB SGはApp SGから3306だけを許可します。SSH ingressはありません。DB route tableはdefault internet routeを持ちません。

ALBはApacheの `/health` を確認します。Apacheは `/health` を静的配信し、その他をlocalhost Tomcatへreverse proxyします。このためDB一時障害はページ上に表示されますが、health自体を直ちに落としません。

## AWS APIとSecret

EC2はIMDSv2でinstance roleの一時credentialを取得し、対象Secret ARNにだけ `GetSecretValue` します。Secret JSONはhost、port、dbname、username、passwordです。TomcatとPython scriptsは実行時取得し、コード/User Dataにはpasswordがありません。NAT有効時はAWS public endpointsへ443、endpoint有効時はPrivate DNS経由でinterface endpointsへ到達します。初期package downloadにはNATが必要です。

## Logs / Metrics / notification

CloudWatch AgentがOS、cloud-init、Apache、Tomcat、application、CodeDeploy logsを各Log Groupへ転送し、memory/disk custom metricsを送信します。metric filtersは `ERROR`、`Exception`、`OutOfMemory`、`Failed` を検知します。ALB、ASG/EC2、RDS、CWAgent、log metricsのalarm actionは共通SNS topicです。Emailはsubscription確認後、SlackはChatbot/User Notificationsの手動Workspace接続後に配送されます。

## CI/CD

```text
Developer -> GitHub push -> CodeConnections -> CodePipeline
  -> CodeBuild Plan -> optional Approval -> CodeBuild Apply
  -> CodeBuild readiness checks -> CodeBuild Maven/package
  -> CodeDeploy tag selection -> hooks -> ROOT.war -> ValidateService
```

bootstrapのstate/artifact bucket、Pipeline、projects、CodeDeploy application/groupは初回ローカル適用で作ります。Deployment Groupは将来作られる `DeployGroup=app_20260902` instanceをtag選択するため、bootstrap時にASGは不要です。

## Patch flow

Maintenance Windowが第1水曜11:00 JSTに `PatchGroup=app_20260902` をtargetにし、SSM service roleから `AWS-RunPatchBaseline` をInstall/RebootIfNeededで実行します。Amazon Linux 2023 baselineはsecurity/bugfixのCritical/Important/Mediumを7日後承認します。

## セキュリティ考慮

Private EC2/RDS、非公開RDS、encryption、IMDSv2、SSHなし、role-based access、Secret限定参照、S3 public block、state versioning/native lockingを採用します。一方、指定CIDRはpublic address、egressはpackage/AWS APIのため広め、apply roleも学習用に広めです。本番ではWAF、egress inspection、KMS CMK、rotation、multi-AZ NAT/RDS、least-privilege分割、CloudTrail/Config/GuardDuty/Flow Logs、backup、immutable AMI、blue-greenを追加します。
