# 複数 Web アプリを同じ Tomcat で動かすためのガイド

## このドキュメントの目的

このプロジェクトでは、1つの AWS インフラ、1つの Tomcat、1つの `ROOT.war` の中で複数の小さな Web アプリを動かせます。

このドキュメントでは、現在の URL 構成、ファイル配置、アプリを追加・差し替えする手順、確認方法をまとめます。

## 現在の構成

現在は、同じ Tomcat アプリケーションの中で次の Web アプリを公開しています。

| URL パス | 内容 | 主な配置場所 |
| --- | --- | --- |
| `/` | アプリ選択用のトップページ | `app/tomcat-app/src/main/webapp/index.html` |
| `/aws-learning/` | AWS 学習用の参考書兼クイズサイト | `app/tomcat-app/src/main/webapp/aws-learning/` |
| `/run-route/` | ランニングコース地図アプリ | `app/tomcat-app/src/main/webapp/run-route/` |
| `/api/status` | Java Servlet による稼働状況 API | `HomeServlet.java` |

デプロイ後の URL は次のようになります。

```text
http://app.filanza-aws.com/
http://app.filanza-aws.com/aws-learning/
http://app.filanza-aws.com/run-route/
http://app.filanza-aws.com/api/status
```

HTTPS 化した場合は、`http` を `https` に読み替えます。

## なぜ複数アプリを動かせるのか

Tomcat では、`ROOT.war` が Web サイトのルートとして展開されます。

このプロジェクトでは、`src/main/webapp` 配下に置いたファイルが、そのまま URL パスに対応します。

例:

```text
src/main/webapp/index.html                -> /
src/main/webapp/aws-learning/index.html   -> /aws-learning/
src/main/webapp/run-route/index.html      -> /run-route/
```

つまり、`src/main/webapp` 配下にディレクトリを分けて配置すれば、1つの WAR の中に複数の静的 Web アプリを共存させられます。

Java Servlet の `/api/status` は、静的ファイルとは別に Java 側で提供されています。AWS 学習サイトなどから API を呼ぶ場合は、相対パスではなく `/api/status` のような絶対パスで呼ぶと、どのサブディレクトリからでも安定して動作します。

## 現在のディレクトリイメージ

```text
app/tomcat-app/src/main/webapp/
├── index.html
├── styles.css
├── aws-learning/
│   ├── index.html
│   ├── styles.css
│   └── app.js
└── run-route/
    ├── index.html
    ├── styles.css
    └── app.js
```

## 新しい Web アプリを追加する手順

新しいアプリを追加する場合は、既存アプリを消さずに新しいディレクトリを追加します。

例として `new-app` を追加する場合:

```bash
mkdir app/tomcat-app/src/main/webapp/new-app
```

配置するファイル例:

```text
app/tomcat-app/src/main/webapp/new-app/index.html
app/tomcat-app/src/main/webapp/new-app/styles.css
app/tomcat-app/src/main/webapp/new-app/app.js
```

次に、トップページにリンクを追加します。

編集対象:

```text
app/tomcat-app/src/main/webapp/index.html
```

追加例:

```html
<a class="app-card" href="new-app/">
  <span class="badge">NEW APP</span>
  <h2>New App Name</h2>
  <p>Short description.</p>
  <strong>開く</strong>
</a>
```

最後に commit、push します。

```bash
git add app/tomcat-app/src/main/webapp
git commit -m "Add new web app"
git push origin main
```

push 後、CodePipeline が起動し、WAR のビルドと EC2/Tomcat へのデプロイが行われます。

## 既存 Web アプリを差し替える手順

既存アプリだけを差し替えたい場合は、対象ディレクトリ配下だけを変更します。

| 差し替えたいアプリ | 変更する場所 |
| --- | --- |
| AWS 学習サイト | `app/tomcat-app/src/main/webapp/aws-learning/` |
| ランニングコース地図アプリ | `app/tomcat-app/src/main/webapp/run-route/` |
| トップページ | `app/tomcat-app/src/main/webapp/index.html` と `styles.css` |

アプリ名、説明文、リンク先を変えない場合は、トップページを編集する必要はありません。

## パス指定の注意点

サブディレクトリで動かす Web アプリでは、CSS や JavaScript のパス指定が重要です。

同じアプリ内のファイルは相対パスで指定します。

```html
<link rel="stylesheet" href="styles.css">
<script src="app.js" defer></script>
```

画像を同じアプリ配下に置く場合も相対パスにします。

```html
<img src="images/example.png" alt="">
```

Java Servlet など共通 API を呼ぶ場合は、絶対パスを使います。

```js
fetch('/api/status')
```

避けたい指定例:

```html
<link rel="stylesheet" href="/styles.css">
```

`/styles.css` と書くと、サブアプリの CSS ではなくトップページ直下の CSS を指します。これにより、画面デザインが崩れることがあります。

## ローカル確認

静的ファイルだけを確認する場合は、簡易 HTTP サーバで確認できます。

```bash
python3 -m http.server 8088 --directory app/tomcat-app/src/main/webapp
```

ブラウザで次を開きます。

```text
http://127.0.0.1:8088/
http://127.0.0.1:8088/aws-learning/
http://127.0.0.1:8088/run-route/
```

この確認では Tomcat の Java Servlet は動きません。そのため `/api/status` など Java 側の API は、本番環境または Tomcat を起動した環境で確認します。

## デプロイ後の確認

デプロイ後は、HTML、CSS、JavaScript が正しい Content-Type で返るか確認します。

```bash
curl -I http://app.filanza-aws.com/
curl -I http://app.filanza-aws.com/aws-learning/
curl -I http://app.filanza-aws.com/run-route/
curl -I http://app.filanza-aws.com/aws-learning/styles.css
curl -I http://app.filanza-aws.com/run-route/styles.css
curl -I http://app.filanza-aws.com/aws-learning/app.js
curl -I http://app.filanza-aws.com/run-route/app.js
```

期待する結果:

| 対象 | 期待値 |
| --- | --- |
| HTML | `200` が返る |
| CSS | `Content-Type: text/css` が返る |
| JavaScript | JavaScript として返る |

CSS が `text/html` で返っている場合は、パス指定ミス、ファイル未配置、Tomcat/Apache の転送設定、または古い WAR が残っている可能性があります。

## ランニングコース地図アプリの注意点

`/run-route/` はブラウザの現在地情報を使います。

ルート作成だけであれば HTTP でも確認できますが、現在地取得やリアルタイム判定を使う場合は HTTPS が必要です。

HTTP の状態で動作確認する場合は、次の操作で確認できます。

1. `/run-route/` を開く
2. `地図中心をスタートにする` をクリックする
3. `舎人公園サンプル` をクリックする
4. `コースを作成` をクリックする

## よくあるトラブル

| 症状 | 主な原因 | 確認ポイント |
| --- | --- | --- |
| 地図タイルがばらばらに表示される | Leaflet CSS が読み込めていない | `run-route/styles.css` と Leaflet 読み込みを確認 |
| CSS が効かない | CSS パスが間違っている | `/styles.css` ではなく `styles.css` になっているか確認 |
| `/run-route/` が 404 になる | WAR にファイルが含まれていない | CodeBuild の成果物と CodeDeploy 結果を確認 |
| 現在地が取れない | HTTPS ではない、またはブラウザ権限が拒否されている | HTTPS 化、ブラウザの位置情報許可を確認 |
| ルート作成が遅い | 外部ルーティング API が遅い | しばらく待つ、または時間を置いて再試行 |
| 高低差が出ない | 標高 API または DEM タイル取得に失敗 | ブラウザの開発者ツールで通信エラーを確認 |

## 変更時の基本ルール

アプリを安全に追加・差し替えするには、次の考え方で進めます。

- 既存アプリを残したい場合は、新しいディレクトリを作る
- 既存アプリだけ変えたい場合は、そのディレクトリ配下だけを編集する
- サブアプリの CSS、JS、画像は相対パスで指定する
- 共通 API は `/api/status` のように絶対パスで指定する
- 変更後はローカル確認、push、CodePipeline、デプロイ後確認の順で進める
