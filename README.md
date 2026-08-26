# ひたすら広告

> 広告を見る。それだけ。以上。

全151種類の架空広告を探索し、広告図鑑の完成を目指すFlutterアプリです。実在する広告ネットワークや広告クリック報酬とは分離されています。

## すぐに起動する

```powershell
flutter pub get
flutter run -d chrome
```

## 品質確認

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-wasm-dry-run
```

## ドキュメント

- [制作環境引き継ぎ説明書](docs/DEVELOPMENT_HANDOFF.md)
- [151広告監査レポート](docs/ad_audit_151.md)
- [仕様書⑥: 151広告・図鑑データの入力元](docs/specification_06_catalog_source.md)
- [仕様書⑦: 現行プロダクト仕様](docs/specification_07_current_product.md)

## 主な構成

- `assets/data/ad_catalog.json`: 151広告の実行時カタログ
- `lib/data`: カタログ読み込みと端末内永続化
- `lib/state`: アプリ状態、発見、視聴記録
- `lib/services`: 広告選択と音声再生
- `lib/widgets`: 広告オーバーレイと広告体験UI
- `lib/screens`: 初回登録、ホーム、記録、探索プロフィール
- `test`: 151広告を含む自動テスト

## 本番デプロイ

`main`へのpush時、GitHub Actionsが解析、テスト、Webビルドを順番に実行します。すべて成功した場合だけ、ビルド済みの`build/web`をVercelへ本番デプロイします。

GitHub Repository Secretsには以下が必要です。Secret値はリポジトリへ保存しません。

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`
