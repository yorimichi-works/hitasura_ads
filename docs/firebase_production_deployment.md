# Firebase Hosting 本番公開手順

## 構成

- 本番URL: `https://hitasura.yorimichi-works.jp/`
- Hosting公開元: `build/web`
- SPA rewrite: 存在しないパスを `/index.html` へrewrite
- CI: `main` pushでanalyze、test、production build、Firebase Hosting live channelへdeploy
- HTTPS: Firebase Hostingが独自ドメイン接続完了後に証明書を自動発行・更新

## Firebaseで利用者が行う準備

1. Firebase Consoleで本番用プロジェクトを作成する。
2. Hostingを開始する。初期ファイルの作成操作は不要。
3. FirebaseプロジェクトIDを控える。
4. Firebase HostingへdeployできるサービスアカウントJSONを安全に取得する。
5. GitHubリポジトリの `Settings > Secrets and variables > Actions` に以下を登録する。

|Secret|値|
|---|---|
|`FIREBASE_SERVICE_ACCOUNT_HITASURAADS`|Firebase CLIがGitHubへ登録したサービスアカウントJSON|

サービスアカウントJSONはリポジトリへ保存しない。GitHub Secrets以外へ貼り付けない。

Googleログインを有効にする場合は、GitHub ActionsのRepository Variableとして
`GOOGLE_WEB_CLIENT_ID`を登録する。未登録の場合、ログインUIは「準備中」と表示される。
OAuthクライアントにはFirebase仮URLと`https://hitasura.yorimichi-works.jp`の実際の
JavaScript生成元を登録する。

## 最初のdeploy

Secrets登録後に `main` へpushするか、GitHubのActions画面から
`Build and Deploy Flutter Web to Firebase Hosting` を手動実行する。

成功後、Firebase Consoleに表示される次の仮URLで先に確認する。

- `https://PROJECT_ID.web.app/`
- `https://PROJECT_ID.firebaseapp.com/`

確認項目:

- `/` が表示される
- 任意の存在しないパスを直接開いてもアプリが表示される
- `robots.txt` と `sitemap.xml` が取得できる
- DevToolsで404、asset欠損、mixed contentがない
- スマホ幅でゲームと図鑑を操作できる

## 独自ドメイン接続の停止地点

Firebase Consoleの `Hosting > Add custom domain` へ進み、
`hitasura.yorimichi-works.jp` を入力するところまでは実施できる。

その次にFirebaseがTXT、CNAME、A、AAAA等のDNSレコードを提示した時点で停止する。
値はプロジェクト・ドメインの状態によって変わるため推測しない。

Firebaseが表示した以下をそのまま記録してから、お名前.comへ登録する。

|確認項目|Firebaseの表示値|
|---|---|
|レコード種別|画面に表示された種別|
|ホスト名|画面に表示されたホスト名|
|値 / VALUE|画面に表示された値|
|TTL|指定があればその値。なければお名前.com既定値|
|削除対象|Firebaseが明示した既存レコードだけ|

所有権確認用TXTは、接続後も削除せず維持する。HTTPS証明書が有効になるまでは、
DNS伝播と証明書発行を待ち、Firebase Consoleが `Connected` を示すまで本番移行完了としない。

## 広告モード

広告ネットワークは `ADMOB_MODE` のビルド時defineで明示する。

### 友人による実機テスト

Google Mobile Ads SDKが提供する正式テスト広告IDだけを使う。

```powershell
flutter build apk --release --dart-define=ADMOB_MODE=test
```

### 本番広告

本番IDを同時に指定したビルドだけが本番広告を使用する。

```powershell
flutter build appbundle --release `
  --dart-define=ADMOB_MODE=production `
  --dart-define=ADMOB_ANDROID_REWARDED_ID=ca-app-pub-REPLACE_WITH_REAL_ID
```

iOSは `ADMOB_IOS_REWARDED_ID` を使用する。IDをソースコードへコミットしない。

### 無効化

```powershell
flutter build web --release --dart-define=ADMOB_MODE=disabled
```

Releaseビルドで `ADMOB_MODE` を省略した場合も安全側の `disabled` になる。
Flutter WebではGoogle Mobile AdsのモバイルSDKを呼ばない。

## ローカル確認

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href / --no-wasm-dry-run `
  --dart-define=APP_ENV=production `
  --dart-define=ADMOB_MODE=disabled `
  --dart-define=APP_BASE_URL=https://hitasura.yorimichi-works.jp
firebase emulators:start --only hosting
```

`.firebaserc.example` は雛形であり、実Project IDを含む `.firebaserc` はローカル専用とする。
