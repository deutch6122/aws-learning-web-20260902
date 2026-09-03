# Multi Web App Routing Guide

## Purpose

This project can serve multiple small web applications from one Tomcat
`ROOT.war`. Each application is placed under a different directory in
`src/main/webapp`, and the root page works as a launcher.

This is useful when you want to keep the same AWS infrastructure while changing
or adding application content.

## Current URL Layout

| URL path | Application | Source files |
| --- | --- | --- |
| `/` | App launcher | `app/tomcat-app/src/main/webapp/index.html`, `styles.css` |
| `/aws-learning/` | AWS Infrastructure Field Guide | `app/tomcat-app/src/main/webapp/aws-learning/` |
| `/run-route/` | RunRoute Japan | `app/tomcat-app/src/main/webapp/run-route/` |
| `/api/status` | Runtime status API | `HomeServlet.java` |

After deployment, the URLs are:

```text
http://app.filanza-aws.com/
http://app.filanza-aws.com/aws-learning/
http://app.filanza-aws.com/run-route/
http://app.filanza-aws.com/api/status
```

If HTTPS is enabled, replace `http` with `https`.

## Why This Works

Tomcat expands `ROOT.war` at the web root. Static files under
`src/main/webapp` are served according to their directory path.

For example:

```text
src/main/webapp/aws-learning/index.html -> /aws-learning/
src/main/webapp/run-route/index.html    -> /run-route/
```

The Java Servlet remains available at `/api/status`. The AWS learning app calls
that API with an absolute path so it works even when the page is opened from
`/aws-learning/`.

## Add Another Web App

1. Create a directory under `app/tomcat-app/src/main/webapp`.

```bash
mkdir app/tomcat-app/src/main/webapp/new-app
```

2. Place the new app files in that directory.

```text
app/tomcat-app/src/main/webapp/new-app/index.html
app/tomcat-app/src/main/webapp/new-app/styles.css
app/tomcat-app/src/main/webapp/new-app/app.js
```

3. Add a link from the root launcher.

Edit:

```text
app/tomcat-app/src/main/webapp/index.html
```

Add:

```html
<a class="app-card" href="new-app/">
  <span class="badge">NEW APP</span>
  <h2>New App Name</h2>
  <p>Short description.</p>
  <strong>開く</strong>
</a>
```

4. Commit and push.

```bash
git add app/tomcat-app/src/main/webapp
git commit -m "Add new web app"
git push origin main
```

CodePipeline then builds the WAR and CodeDeploy publishes the new files.

## Replace One Existing App

To replace only the running map app, edit files under:

```text
app/tomcat-app/src/main/webapp/run-route/
```

To replace only the AWS learning app, edit files under:

```text
app/tomcat-app/src/main/webapp/aws-learning/
```

Do not edit the root launcher unless the app name, description, or link needs
to change.

## Important Path Rules

- Use relative paths for assets inside the same app directory:
  - `styles.css`
  - `app.js`
  - `images/example.png`
- Use absolute paths for shared Java Servlet APIs:
  - `/api/status`
- Avoid linking to `/styles.css` from sub apps because that points to the root
  launcher stylesheet, not the app stylesheet.

## Validation

Local static preview:

```bash
python3 -m http.server 8088 --directory app/tomcat-app/src/main/webapp
```

Open:

```text
http://127.0.0.1:8088/
http://127.0.0.1:8088/aws-learning/
http://127.0.0.1:8088/run-route/
```

Post-deploy checks:

```bash
curl -I http://app.filanza-aws.com/
curl -I http://app.filanza-aws.com/aws-learning/
curl -I http://app.filanza-aws.com/run-route/
curl -I http://app.filanza-aws.com/aws-learning/styles.css
curl -I http://app.filanza-aws.com/run-route/styles.css
```

Expected results:

- HTML pages return `200`.
- CSS files return `Content-Type: text/css`.
- JavaScript files return JavaScript content.

## Notes for the Running Map App

The running map app uses browser geolocation. On the deployed domain, real-time
current-location tracking requires HTTPS. Route creation can still be tested
without HTTPS by using `地図中心をスタートにする` and `皇居周辺サンプル`.
