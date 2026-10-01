# モバイル版リリース準備（2026-10-01）

## iOSビルド対象の追加機能

- スタミナ全回復時と、アプリを3日間起動していないときのローカル通知。設定画面からオフにできる。OSの省電力制御により到着時刻は多少前後する。
- iOS AdMobアプリID `ca-app-pub-3186852093801241~9948289508`、全回復用リワード広告ユニット `ca-app-pub-3186852093801241/4511295842`、任意解放用ユニット `ca-app-pub-3186852093801241/6036789642` を設定。Androidの本番ユニットは未提供のため別途設定が必要。
- 買い切り商品ID `ad_free_unlimited` をiOS/Android両ストアで同じ非消耗型商品として登録する。価格は各ストアで200円に設定し、アプリ画面にはストアが返す価格を表示する。購入済みならチケットを消費せず、図鑑から好きな広告をスポンサー視聴なしで解放できる。購入復元ボタンあり。
- 購入権利は端末に保存し、再インストール時はストアの復元操作で戻す。現実の販売前にストア側の商品登録、Sandbox/内部テストでの購入・復元検証、必要な取引検証方式の確定が必要。
- `codemagic.yaml` に署名不要のiOSシミュレータビルドを用意。署名付きIPAには正式なBundle IDと配布プロファイルが必要。

## 今回確認・修正した問題

- 日付をまたいで起動し続けると、前日の視聴時間が当日の集計に混ざる問題を修正。
- 「次の広告」を連打すると、画面遷移の待機中にチケットを重複消費できる問題を修正。
- 本番リワード広告ユニットIDが未設定でも広告ボタンが有効に見える問題を修正。
- モバイルのGoogleログイン画面はクラウド同期につながっていなかったため、ユーザー指示に従いログイン・同期とWeb版を削除。既存の端末内進捗は従来の保存キーから読み込む。
- Androidのリリースビルドがデバッグ鍵を使用していた設定を廃止。必要なアプリID、AdMobアプリID、署名情報が欠けたリリースビルドは失敗させる。
- WindowsでAndroidビルド中、Gradle JVMがメモリ不足で終了したため、ヒープ上限とワーカー数を縮小。
- Web公開ワークフローを廃止し、解析・テスト・Androidデバッグビルドを行うCIに変更。

## リリース前に設定が必要なもの

1. Androidの正式な `ANDROID_APPLICATION_ID` とiOSの `PRODUCT_BUNDLE_IDENTIFIER` を決定する。現行の `com.example.*` は仮値。
2. AndroidのGradleプロパティ `RELEASE_STORE_FILE`、`RELEASE_STORE_PASSWORD`、`RELEASE_KEY_ALIAS`、`RELEASE_KEY_PASSWORD` を安全な場所から渡す。鍵をリポジトリに追加しない。
3. AndroidのGradleプロパティ `ADMOB_ANDROID_APP_ID`、iOSのRelease用 `ADMOB_APP_ID`、Dart定義 `ADMOB_MODE=production` と各OSの `ADMOB_ANDROID_REWARDED_ID` / `ADMOB_IOS_REWARDED_ID` に本番値を設定する。現在のiOS Release設定はテスト用アプリIDのまま。
4. Android実機で広告の表示・視聴完了時のみ報酬付与・音声・画面遷移を確認する。iOSはmacOS環境でビルドと実機確認を行う。
5. ストア登録用の説明、画像、プライバシー案内を用意する。端末内の進捗はアプリ削除時に消え、旧Web版のクラウド進捗は引き継がれないことを明記する。
6. 既に公開したFirebase HostingのWeb版は、リポジトリからコードとデプロイ処理を削除しても自動的には停止しない。公開停止とクラウド上の既存データの扱いを別途決める。

## 検証

- `flutter analyze --no-pub`
- `flutter test --no-pub`（151ゲームのスモークテストを含む）
- `flutter build apk --debug --no-pub`

WindowsではDeveloper Modeが無効だと、未使用のWindowsデスクトップ向けプラグインのシンボリックリンク作成で `flutter pub get` が終了する。この環境では `flutter config --no-enable-windows-desktop` → `flutter pub get` → `flutter config --enable-windows-desktop` の順で生成ファイルを更新した。CIのLinux環境では通常の `flutter pub get` を実行する。
