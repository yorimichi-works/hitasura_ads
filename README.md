# ひたすら広告

> 広告を見る。それだけ。

アプリ内で描画される全151種類の架空広告を見て、広告図鑑の完成を目指すFlutterアプリです。実在の広告ネットワークや広告クリック報酬とは分離されています。

## 主な画面

- ホーム: 中央の「広告を再生する」から探索広告を開始
- 記録: 広告図鑑、探索時間、視聴回数、ランキング
- 広告探索: 実際の広告同意とは分離された探索プロフィール

No.151「幻の広告 ― アドゴン」は、No.001〜150をすべて発見した後だけ出現します。

## ローカル実行

```powershell
flutter pub get
flutter run -d chrome
```

## 品質確認

```powershell
flutter analyze
flutter test
flutter build web --release --base-href /
```

## データ構成

- `assets/data/ad_catalog.json`: 151広告の正式名称、説明、表示・操作・演出定義
- `lib/data`: カタログと永続化境界
- `lib/state`: アプリ状態と発見・視聴記録
- `lib/services`: 通常広告とNo.151の抽選規則
- `lib/widgets`: 広告オーバーレイと共通広告エンジン
- `lib/screens`: ホーム、記録、図鑑、広告探索

データはMVPでは端末内へ保存します。`AppStore`を実装すればFirebase等へ差し替えられます。

## 本番デプロイ

`main`へのpush時にGitHub Actionsが解析、テスト、Webビルドを行い、成功した`build/web`だけをVercelへproduction deployします。GitHub Repository Secretsに以下が必要です。

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`
