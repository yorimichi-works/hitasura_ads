# ひたすら広告 — AD DEMO 151

> 広告を、ひたすら遊ぶ。

スマホでよく見るゲーム広告の「デモ」だけを151本つまみ食いできるミニゲーム集です（Flutter / Web・Android・iOS）。
ピン抜き、ゲート×100ランナー、極寒サバイバル、ラーメン屋経営、マリオパーティ風の対戦、5秒のミニミニゲーム、
ドット絵の横スクロール、ローポリ3D、10連ガチャ、広告そのものをいじるパロディまで。通常150本＋全発見で現れる秘密の1本。
20言語対応（日本語・英語・中国語簡体/繁体・韓国語・スペイン語・フランス語・ドイツ語・ポルトガル語・ロシア語・イタリア語・
ヒンディー語・ベンガル語・アラビア語・ウルドゥー語・ペルシャ語・インドネシア語・トルコ語・ベトナム語・タイ語。右から左の表示にも対応）。

## 遊び方

- **次の広告を見る**：広告チケット（最大5枚・3分で1枚回復）を1枚使うと、チャンネルが回って広告デモが始まります。
  クリアでスター（最大3）・コイン・経験値。終わるとウソのストアページ（「インストール」は押しても……）。
- **発見演出**：初めて見た広告はカプセル演出で図鑑へ登録。SUPER RAREは虹色。
- **広告ラッシュ**：見つけた短い広告を連続で。クリアするほど速くなるワリオ風モード（ライフ4）。
- **広告図鑑**：実際のゲーム画面がサムネイル。発見済みはいつでも無料で再プレイ。
- **広告カプセル / デイリーボーナス**：コインで未発見の広告を解放。
- スポンサー広告（任意）でチケット全回復・未発見広告の解放。

## 起動

```powershell
flutter pub get
flutter run -d chrome                               # 本編
flutter run -d chrome -t lib/playtest_main.dart     # 開発用：151本を番号から直接プレイ（言語・速度切替つき）
```

## 構成

| パス | 内容 |
|---|---|
| `lib/arcade/engine/` | ミニゲームエンジン：ゲームループ／HUD（`game_view.dart`）、描画ヘルパ（`draw.dart`）、パーティクル（`fx.dart`）、ドット絵（`pixel.dart`）、軽量3D（`mini3d.dart`）、音（`audio*.dart`、Webは `web/arcade_audio.js` のWeb Audio） |
| `lib/arcade/games/gNNN.dart` | 151本のゲーム本体（1ファイル1本） |
| `lib/arcade/registry.dart` | 生成物。`tool/arcade/lineup.json` から `python tool/arcade/gen_registry.py` |
| `lib/ui/` | ホーム・広告再生（ルーレット→タイトル→ゲーム→ストア風エンドカード）・発見演出・図鑑・ラッシュ・設定 |
| `lib/l10n/` | 20言語。`tool/l10n/<code>.json` → `python tool/l10n/gen_l10n.py build` |
| `lib/state/app_controller.dart` | 発見・スター・コイン・経験値・チケット・クラウド同期 |
| `assets/audio/{sfx,bgm}/` | 効果音100種・BGM18曲。すべて `python tool/audio/synth.py` で合成 |
| `tool/arcade/GAME_DEV_GUIDE.md` | ミニゲーム制作ガイド（API・品質基準・テスト方法） |

## テスト

```powershell
flutter analyze
flutter test                                  # 151本を自動操作で完走させるスモークテストを含む
python tool/arcade/snap.py 12,13              # 指定ゲームだけ実行し build/snaps/ にスクリーンショット
```

## 本番デプロイ

`main` へのpush時、GitHub Actionsが解析・テスト・Webビルドを実行し、成功時のみFirebase Hosting（`hitasuraads`）へデプロイします
（`.github/workflows/deploy-firebase-hosting.yml`、Secret `FIREBASE_SERVICE_ACCOUNT_HITASURAADS`）。
Firestoreのルール（`firestore.rules`）に新フィールド `arcade` を追加しているため、ルールのデプロイも必要です。
