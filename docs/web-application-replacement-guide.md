# Web教材差し替え・デプロイ手順書

## 1. 目的

本書は、EC2上のApache HTTP Server / Tomcatで公開するWeb資材を更新し、既存のCodePipelineで安全にデプロイする手順を説明します。

対象はこのrepositoryのJava 17 / Tomcat / Maven構成です。インフラを作り直さず、`ROOT.war` に含める教材本文・デザイン・問題・Java APIを変更します。

## 2. 「差し替えるもの」の正体

利用者が直接WARファイルを編集するのではありません。sourceを変更し、CodeBuildがMavenで新しいWARを生成します。

```text
app/tomcat-app/src/main/webapp/index.html   教材本文（1ページ）
app/tomcat-app/src/main/webapp/styles.css  デザイン
app/tomcat-app/src/main/webapp/app.js      問題判定・章ナビ・API表示
app/tomcat-app/src/main/java/...           稼働情報・DB参照API
                         │
                         └─ mvn package → target/ROOT.war
                                              │
                                              └─ CodeDeploy → /opt/tomcat/webapps/ROOT.war
```

「`index.html` 1枚」は1ページ構成を意味します。保守性とcache制御のため、CSSとJavaScriptは別ファイルにしていますが、すべて同じWARへ格納されます。

## 3. 変更範囲と責務

| 変更したい内容 | 編集対象 | Infrastructure変更 |
| --- | --- | --- |
| 章本文、見出し、問題文 | `src/main/webapp/index.html` | 不要 |
| 色、余白、responsive layout | `src/main/webapp/styles.css` | 不要 |
| 正誤判定、score、navigation | `src/main/webapp/app.js` | 不要 |
| DB status JSONの項目 | `HomeServlet.java` と `app.js` | 通常不要 |
| Maven dependency / Java version | `pom.xml` | EC2/Tomcatとの互換性確認が必要 |
| domain、ALB、RDS、EC2、IAM | `infra` | 必要 |
| PipelineやCodeBuild project | `bootstrap` | 必要 |

教材だけを更新するときは、原則として `app/tomcat-app` 以外を変更しません。

## 4. 現行アプリのinterface contract

### 4.1 Browser向けURL

| Path | 応答元 | 用途 | DB依存 |
| --- | --- | --- | --- |
| `/` | Tomcat default servlet | `index.html` と教材画面 | なし |
| `/styles.css` | Tomcat default servlet | CSS | なし |
| `/app.js` | Tomcat default servlet | JavaScript | なし |
| `/api/status` | `HomeServlet` | EC2情報、DB状態、messagesをJSON返却 | あり |
| `/health` | Apache | ALB health check用の静的 `OK` | なし |

`/api/status` が失敗しても、`index.html`、CSS、JavaScriptは表示できます。画面は「静的教材モード」となり、DB情報だけが非表示になります。

### 4.2 `/api/status` のJSON形式

値は環境ごとに変わるため、field名をinterfaceとして扱います。

```json
{
  "dbStatus": "Connected to Amazon RDS MySQL",
  "dbConnected": true,
  "currentTime": "<ISO-8601 timestamp>",
  "instanceId": "i-************1234",
  "availabilityZone": "<availability-zone>",
  "appVersion": "<version>",
  "messages": [
    {
      "title": "<title>",
      "body": "<body>",
      "createdAt": "<timestamp>"
    }
  ]
}
```

APIはSecret value、password、database host、ARN、Access Keyをbrowserへ返しません。instance IDも完全値ではなく末尾4文字だけのmasked表示です。新しいfieldを追加するときも機密情報や不要な運用識別子を含めないでください。

## 5. 教材を編集する

### 5.1 作業branchを作成

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/update-learning-content
```

### 5.2 本文と問題を変更

`app/tomcat-app/src/main/webapp/index.html` を編集します。

○×問題は次の構造を維持します。

```html
<div class="quiz-card" data-kind="boolean" data-correct="true">
  <p><span>Q1</span>問題文</p>
  <div class="answer-buttons">
    <button type="button" data-choice="true">○ 正しい</button>
    <button type="button" data-choice="false">× 誤り</button>
  </div>
  <div class="quiz-feedback" hidden></div>
  <p class="quiz-explanation" hidden>解説文</p>
</div>
```

トラブルシュート問題では、正解optionだけに `data-correct="true"` を付けます。

```html
<div class="quiz-card" data-kind="choice">
  <button type="button" data-choice="a">A. 選択肢</button>
  <button type="button" data-choice="b" data-correct="true">B. 正解</button>
  <div class="quiz-feedback" hidden></div>
  <p class="quiz-explanation" hidden>解説文</p>
</div>
```

問題数はJavaScriptが `.quiz-card` の件数から自動計算します。問題番号の重複や欠番は目視または検索で確認します。

### 5.3 章を追加・削除

章の `<section id="chapter-N">` を変更した場合は、次の3か所を同じanchorへ揃えます。

1. desktop用 `.sidebar nav` のlink
2. mobile用 `#chapter-select` のoption
3. 本文sectionの `id`

### 5.4 Java APIを変更

`HomeServlet.java` のresponse recordを変更した場合は、`app.js` の参照fieldも同時に変更します。JSONへ任意文字列をHTMLとして挿入せず、`textContent` を使ってXSSを防ぎます。

## 6. local検証

### 6.1 Source差分と秘密情報

macOSに`rg`がない場合は`grep`を使用できます。`.git`、Terraform cache、build outputは除外します。

```bash
git diff --check
git diff -- app/tomcat-app docs

grep -RInE '([0-9]{12}|AKIA[0-9A-Z]{16}|password[[:space:]]*=|secret_access_key|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)' \
  --exclude-dir=.git \
  --exclude-dir=.terraform \
  --exclude-dir=target \
  app docs
```

検出結果は機械的に全削除せず、exampleのfield名か実値かを確認します。実account ID、email、Secret ARN suffix、Connection ID、domainなども公開方針に従って匿名化します。

### 6.2 Maven build

Java 17とMavenを用意して実行します。

```bash
mvn -f app/tomcat-app/pom.xml clean package
test -s app/tomcat-app/target/ROOT.war
jar tf app/tomcat-app/target/ROOT.war | grep -E '(^index.html$|^styles.css$|^app.js$|HomeServlet.class$)'
```

期待する4種類の資材がWAR内に表示されることを確認します。

### 6.3 静的preview

WARを展開せず、source directoryを一時的に配信して見た目と問題操作を確認できます。

```bash
python3 -m http.server 8088 --directory app/tomcat-app/src/main/webapp
```

別terminalまたはbrowserから `http://127.0.0.1:8088/` を開きます。Java APIは動かないため「静的教材モード」になりますが、次を確認できます。

- desktop/mobileで横scrollや文字の重なりがない
- 章navigationが正しいsectionへ移動する
- ○×20問とトラブルシュート5問が判定される
- 解説、score、resetが動作する
- keyboardのTab/Enterでも回答できる

終了時はserverを実行したterminalで `Ctrl+C` を押します。

### 6.4 Tomcatでの統合確認（任意）

local Tomcat 10環境がある場合は `ROOT.war` をwebappsへ配置し、`DB_SECRET_ARN` 未設定時でも教材が表示されることを確認します。AWS外ではIMDSとSecret取得が失敗するため、DB statusが失敗になるのは想定内です。

## 7. commit・push・自動デプロイ

### 7.1 Commit前確認

```bash
git status --short
git diff --check
git diff --stat
git add app/tomcat-app docs/web-application-replacement-guide.md
git commit -m "Replace application with AWS learning guide"
git push origin feature/update-learning-content
```

review後にmainへmergeします。mainへのpushを検知すると既存Pipelineが開始します。手動開始する場合は実環境名を変数へ入れます。

```bash
PIPELINE_NAME="<pipeline-name>"
AWS_REGION="<aws-region>"

aws codepipeline start-pipeline-execution \
  --name "$PIPELINE_NAME" \
  --region "$AWS_REGION"
```

### 7.2 Pipeline内で起きる処理

```text
GitHub source
  → Terraform validate / plan
  → Terraform apply
  → infrastructure readiness wait
  → mvn clean package
  → ROOT.war + AppSpec + scriptsをartifact化
  → CodeDeployがEC2へ配布
  → check_db.py / seed_db.py
  → Tomcat・Apache restart
  → /health と / の検証
```

教材だけの変更でも現行PipelineはTerraform stageを通ります。planに意図しないinfrastructure差分がある場合は、application変更だからと無視せず停止して原因を確認します。

## 8. デプロイ後確認

同じpipeline execution IDだけを追跡します。

```bash
aws codepipeline get-pipeline-state \
  --name "$PIPELINE_NAME" \
  --region "$AWS_REGION" \
  --query 'stageStates[].{Stage:stageName,Status:latestExecution.status,ExecId:latestExecution.pipelineExecutionId}' \
  --output table
```

公開先を変数に設定して確認します。

```bash
APP_URL="https://<application-domain>"

curl -fsS "$APP_URL/health"
curl -fsSI "$APP_URL/"
curl -fsSI "$APP_URL/styles.css"
curl -fsSI "$APP_URL/app.js"
curl -fsS "$APP_URL/api/status"
```

判定基準は次のとおりです。

| 確認 | 正常条件 |
| --- | --- |
| `/health` | HTTP 200、bodyが`OK` |
| `/` | HTTP 200、`Content-Type: text/html` |
| `/styles.css` | HTTP 200、`Content-Type: text/css`。HTMLを返していない |
| `/app.js` | HTTP 200、JavaScriptのContent-Type |
| `/api/status` | JSON。Secret valueやdatabase passwordを含まず、instance IDもmasked表示 |
| Browser | design、navigation、25問、DB statusを確認 |

`curl /api/status` のoutputをticketや公開logへ貼る場合、instance ID等の運用情報も公開範囲を確認します。

## 9. 失敗時の切り分け

| 症状 | 最初に見る場所 | 主な確認 |
| --- | --- | --- |
| Source失敗 | CodePipeline action | Connection状態、GitHub App repository access |
| Build失敗 | CodeBuild log | Maven compile、dependency、WAR生成 |
| Deploy失敗 | CodeDeploy lifecycle event | 失敗hook、exit code、log tail |
| AfterInstall DB timeout | EC2/RDS/SG | RDS available、App SG→DB SG:3306、DNS |
| `/health`失敗 | Apache / ALB target | httpd、静的health file、target group |
| `/`失敗 | Tomcat | service status、ROOT.war、catalina log |
| CSSだけ反映されない | HTTP header/body | asset path、WAR内容、Servlet mapping、browser cache |
| 教材は表示・DBだけ失敗 | `/api/status`とTomcat log | EC2 Role、Secret ARN、Secrets Manager到達性、RDS |

PythonやSDKのdeprecation warningと、最後に発生したconnection timeoutなどの直接的なerrorを分けて読みます。

## 10. Rollback

### 10.1 推奨: Gitで戻して再デプロイ

公開済みcommitを確認し、誤った変更commitを打ち消します。

```bash
git log --oneline -10
git revert <bad-commit-sha>
git push origin main
```

履歴を残したままPipelineが旧資材相当のWARをbuild・deployします。共有branchで `reset --hard` やforce pushは行いません。

### 10.2 緊急時: 以前のrevisionを再配布

CodeDeployで以前成功したrevisionを指定して再deployする方法もあります。ただしGitのmainと実環境が一時的に不一致になります。緊急復旧後、必ずGit側にもrollbackを反映し、次回deployで元に戻らないようにします。

### 10.3 Rollback後の確認

`/health` だけで完了とせず、`/`、CSS/JavaScript、`/api/status`、問題操作まで再確認します。

## 11. 変更してはいけない情報

次の実値をHTML、JavaScript、README、screenshot、commit message、issue、build logへ保存しません。

- AWS account ID、IAM user/roleの不要な個人情報
- Access Key ID、Secret Access Key、session token
- Secrets ManagerのSecret value、RDS password
- private key、certificate private key
- 個人email、private domain、Connection ID
- Terraform state、plan binary、`.terraform` directory

browserに渡す必要がない値はserver側だけで扱います。公開教材内では `<account-id>`、`<secret-arn>`、`<application-domain>` のようなplaceholderを使用します。

## 12. 完了条件

- Maven buildが成功し、`ROOT.war` にHTML/CSS/JavaScript/Servlet classが含まれる
- Pipelineの同一executionで全stageが成功する
- `/health`、`/`、asset、`/api/status` が期待するContent-Typeとbodyを返す
- desktop/mobileでdesignが崩れない
- ○×20問とtroubleshoot5問、解説、score、resetが動作する
- DB接続中はseed dataが表示され、DB障害時も教材本文を利用できる
- 公開sourceと画面に秘密情報がない
- Rollback手順を実行できる状態である
