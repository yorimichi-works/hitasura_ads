# 『ひたすら広告』制作環境引き継ぎ説明書

最終更新: 2026-08-26

この文書は、別のWindows PCへ制作環境を移し、同じ状態から開発、テスト、Web本番デプロイを再開するための手順書です。

## 1. 現在の完成状態

- Flutter Webアプリとして起動、解析、テスト、リリースビルドが可能
- `AD_001`から`AD_151`までの151広告を収録
- 広告表示、視聴時間、視聴回数、発見種類数、広告図鑑を実装
- No.151の解放条件、専用演出、BGM、効果音を実装
- 初回登録と広告探索プロフィールを実装
- `main`へのpushを起点にVercelへ本番デプロイするGitHub Actionsを設定
- 151広告すべてをスマートフォン相当サイズで生成し、操作とオーバーフローを検査する自動テストを実装

現在のMVPはローカル版です。Firebase、実広告SDK、オンライン世界ランキングはまだ接続していません。ユーザー情報、発見状況、統計は`shared_preferences`を通じて端末内へ保存されます。

## 2. 基準環境

動作確認済みの基準は以下です。

| 項目 | バージョン・内容 |
| --- | --- |
| OS | Windows |
| Flutter | 3.47.1 stable |
| Dart | 3.13.1 |
| DevTools | 2.60.0 |
| Web実行先 | Google Chrome |
| Gitブランチ | `main` |
| Git remote | `https://github.com/chikuzensaito-dev/hitasura_ads.git` |

`pubspec.yaml`のDart SDK条件は`^3.13.1`です。再現性を優先する場合はFlutter 3.47.1を使用してください。将来のstableを使う場合は、必ず解析、全テスト、Webビルドを通してからpushします。

## 3. 新しいPCに必要なもの

1. Git for Windows
2. Flutter SDK stable
3. Google Chrome
4. Visual Studio CodeとFlutter/Dart拡張機能（任意）
5. Android版も扱う場合のみAndroid Studio、Android SDK、エミュレーター

Flutter SDKの`bin`をユーザー環境変数`PATH`へ追加した後、新しいPowerShellを開きます。

```powershell
flutter channel stable
flutter upgrade
flutter doctor -v
```

`flutter doctor -v`でWeb開発に必要なFlutter、Chromeが認識されていれば、Web版の作業を開始できます。Android関連の警告は、Web版だけを扱う場合は作業を妨げません。

## 4. リポジトリを引き継ぐ

```powershell
cd C:\Users\<ユーザー名>\develop
git clone https://github.com/chikuzensaito-dev/hitasura_ads.git
cd hitasura_ads
git switch main
git pull --ff-only origin main
flutter pub get
```

GitHubの認証にはGit Credential Manager、SSH、またはGitHub CLIのいずれかを使用します。アクセストークンをファイルやソースコードへ書かないでください。

## 5. 最初の動作確認

次を上から順に実行します。

```powershell
flutter doctor -v
flutter analyze
flutter test
flutter build web --release --base-href / --no-wasm-dry-run
flutter run -d chrome
```

期待結果は次のとおりです。

- `flutter analyze`: `No issues found!`
- `flutter test`: 全テスト成功
- `flutter build web`: `build/web`が生成される
- Chrome: 初回登録からホームを開き、広告を表示できる

`build/web`は生成物なのでGitへ追加しません。

## 6. プロジェクト構造

| パス | 役割 |
| --- | --- |
| `lib/main.dart` | Flutterの起動点 |
| `lib/app.dart` | `MaterialApp`と初回登録・メイン画面の切り替え |
| `lib/state/app_controller.dart` | アプリ状態、登録、発見、統計、保存処理の中心 |
| `lib/data/ad_catalog.dart` | JSONカタログの読み込み |
| `lib/data/app_store.dart` | 永続化境界。端末版とテスト用メモリ版を提供 |
| `lib/services/ad_selection_service.dart` | 通常広告とNo.151の抽選規則 |
| `lib/services/ad_audio_manager.dart` | BGM、効果音、再生失敗時の安全なフォールバック |
| `lib/widgets/ad_experience_overlay.dart` | 広告体験、カウントダウン、操作、固定値表示 |
| `lib/screens` | 初回登録、ホーム、記録、探索プロフィールの画面群 |
| `assets/data/ad_catalog.json` | アプリが実際に読む151広告データ |
| `assets/audio` | No.151とUIのWAV音源 |
| `test/widget_test.dart` | 基本動作テスト |
| `test/catalog_audit_test.dart` | 151広告の内容、表示、操作、画面崩れ監査 |
| `tool/generate_catalog.dart` | 仕様書⑥からJSONを再生成するツール |
| `tool/generate_audio_assets.dart` | WAV音源を再生成するツール |
| `tool/generate_audit_report.dart` | 151広告監査レポートを再生成するツール |

## 7. 151広告を変更する時のルール

実行時の正本は`assets/data/ad_catalog.json`です。再生成の入力元は`docs/specification_06_catalog_source.md`、現行UIの判断基準は`docs/specification_07_current_product.md`です。

カタログ全体を再生成する場合:

```powershell
dart run tool/generate_catalog.dart docs/specification_06_catalog_source.md assets/data/ad_catalog.json
dart run tool/generate_audit_report.dart
flutter test
```

音源を再生成する場合:

```powershell
dart run tool/generate_audio_assets.dart
flutter test
```

変更時は以下を守ります。

- IDは`AD_001`から`AD_151`まで重複、欠番、追加を発生させない
- 正式名称と説明は仕様書⑥に合わせる
- 固有の数字や文言はJSONの`experience.fixedValues`を唯一の表示元にする
- UI側で広告番号から別の数字や意味を推測しない
- `displayType`と`interactionType`を広告内容に一致させる
- `AD_151`は最高レアリティとし、`AD_001`から`AD_150`の全発見後だけ候補に入れる
- 実在企業、実在サービス、実広告クリエイティブをコピーしない
- 実広告に見える装飾とアプリ操作を誤認させる配置を作らない

変更後は`docs/ad_audit_151.md`も再生成し、差分を確認します。

## 8. 保存データの扱い

現在の保存先は端末ローカルのSharedPreferencesです。

- Chromeではブラウザプロファイルとサイトのオリジンごとに保存される
- 別PCへGitをcloneしても、ユーザー名、発見状況、統計は移行されない
- `localhost`のポートや本番URLが変わると、別の保存領域として扱われる場合がある
- ブラウザのサイトデータ削除やアプリのアンインストールで進捗が消える

開発中に初回状態へ戻す場合は、Chrome DevToolsのApplicationから対象サイトのStorageを消去します。実ユーザーのデータ移行や複数端末同期が必要になった時は、`AppStore`実装をFirebase版へ差し替える方針です。探索プロフィールと広告・トラッキング同意は、将来も別データとして扱います。

## 9. テスト方針

コード変更の最低完了条件は次の3コマンドがすべて成功することです。

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-wasm-dry-run
```

`test/catalog_audit_test.dart`は151広告すべてを390x844相当で描画し、該当する操作を実行し、Flutterの描画例外やオーバーフローを検査します。広告データ、広告UI、共通オーバーレイを変更した場合は、このテストを省略しないでください。

手動確認では最低限、以下を確認します。

- 初回登録からホームへ遷移できる
- 広告の開始、完了、閉じる操作ができる
- 発見済み件数と図鑑表示が一致する
- 記録画面とランキング表示が開く
- 探索プロフィールを保存して再起動後も保持する
- スマートフォン幅とデスクトップ幅の両方で操作できる
- No.151の専用画面と音声が、ユーザー操作後に正しく開始する

## 10. Git運用

作業開始時:

```powershell
git switch main
git pull --ff-only origin main
git status
```

作業完了時:

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-wasm-dry-run
git status
git diff --check
git add .
git commit -m "変更内容を表す短いメッセージ"
git push origin main
```

`main`へのpushは本番デプロイを起動します。未検証の変更、Secret、個人ファイル、大容量の一時ファイルを含めないでください。複数人で同時開発する場合は作業ブランチとPull Requestを使用し、検証後に`main`へマージする方が安全です。

## 11. GitHub ActionsとGitHub Pages

CI/CD定義は`.github/workflows/deploy-web.yml`です。`main`へのpush時に次を実行します。

1. ソースをcheckout
2. Flutter stableをセットアップ
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test`
6. GitHub Pagesを設定
7. `flutter build web --release --base-href /hitasura_ads/ --no-wasm-dry-run`
8. ビルド成果物をPages artifactとしてアップロード
9. 成功した成果物だけをGitHub Pagesへデプロイ

解析、テスト、ビルドのいずれかが失敗した場合はデプロイ工程へ進まないため、既存の本番サイトは維持されます。

公開URLは `https://chikuzensaito-dev.github.io/hitasura_ads/` です。

初回のみ、GitHubリポジトリの `Settings > Pages > Build and deployment > Source` で `GitHub Actions` を選択します。Vercel用Secretは不要です。

Pages用の権限はワークフロー内の `pages: write` と `id-token: write` で宣言しています。

## 12. 現在未接続の機能

引き継ぎ時点で、以下は意図的に未接続です。

- Firebase Authentication
- Cloud Firestore
- オンラインの実ユーザーランキング
- Google Mobile Ads SDK、AdMob等の実広告ネットワーク
- 端末間の進捗同期とバックアップ

画面上の探索広告はアプリ内で作った架空コンテンツです。実広告SDKを導入する場合は、導入時点の最新ポリシー、同意管理、年齢要件、プライバシー要件を改めて確認し、探索プロフィールを本人属性として広告ネットワークへ送らないでください。

## 13. Googleログイン

設定画面に`GoogleAuthService`（`lib/services/google_auth_service.dart`）経由のGoogleログインUIを実装済みです。Web版のOAuth Client IDは公開識別子として既定値を設定しています。別環境ではビルド時のdefineで上書きできます。

```powershell
flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
```

WebのOAuthクライアントには、実際に利用する各URLを「承認済みのJavaScript生成元」として登録します。クライアントシークレットはブラウザログインでは使用せず、ソースコードやGitHubへ保存しません。Android/iOS版を扱う場合は、各プラットフォーム用のOAuth設定も別途必要です。

## 14. 背景BGM

広告ゲーム中のBGM 3曲（8bit27、8bit28、ネオロック82）は魔王魂（https://maou.audio/、作曲：森田交一）の公式ループ音源です。待機・図鑑・プロフィール画面では再生せず、広告ゲームのオーバーレイ表示中だけ再生します。商用利用可・著作表記必須のライセンスのため、設定画面に「音楽：魔王魂」のクレジットを表示しています。詳細は`THIRD_PARTY_NOTICES.md`を参照してください。差し替える場合も同ライセンスの範囲を守ってください。

## 15. トラブルシューティング

依存関係がおかしい場合:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

Chromeが実行先に出ない場合:

```powershell
flutter devices
flutter doctor -v
```

Web音声が自動再生されない場合は、ブラウザの自動再生制限を確認します。音声はユーザー操作を起点に再生する設計で、再生失敗がアプリ全体を停止させないようフォールバックされています。

Vercelで直接URLだけ404になる場合は、デプロイ成果物に`vercel.json`が含まれているか、rewriteが`/index.html`を指しているか確認します。

GitHub Actionsが失敗した場合は、GitHubの`Actions`タブで最初に失敗した工程を確認します。Secret値をログやIssueへ貼り付けないでください。

## 14. 引き継ぎ完了チェックリスト

- GitHubへログインしてcloneとpushができる
- `flutter doctor -v`でFlutterとChromeが認識される
- `flutter pub get`が成功する
- `flutter analyze`が警告なしで成功する
- `flutter test`が全件成功する
- `flutter build web --release --base-href / --no-wasm-dry-run`が成功する
- `flutter run -d chrome`で初回登録から広告表示まで確認できる
- `docs/specification_06_catalog_source.md`と`docs/specification_07_current_product.md`を読める
- GitHub Actionsの3つのVercel Secretsが登録済みである
- `main`へのpush後、Actions成功とVercel本番反映を確認できる

このチェックリストがすべて通れば、制作環境の引き継ぎは完了です。
