# App Store メディア（スクショ・プレビュー動画）引き継ぎ

作成日: 2026-10-07 / ブランチ: `pv/latest-media`
ベース: `origin/codex/storefront-price-diagnostic-20261004`（55c0d7f）
（ホーム購入導線と、レーティング対策で改修した7ゲームを含む最新のアプリコード）

## 成果物

| 種類 | 場所 | 内容 |
| --- | --- | --- |
| スクショ iPhone 6.9" | `store/app_store/<lang>/iphone_6_9/01〜06_*.png` | 1320×2868、RGB（透過なし） |
| スクショ iPad 13" | `store/app_store/<lang>/ipad_13/01〜06_*.png` | 2064×2752、RGB（透過なし） |
| 確認用一覧 | 各フォルダの `contact_sheet.jpg` | 6枚を横並びにした縮小版 |
| プレビュー動画 | `store/app_store/pv/PV_<lang>.mp4` | 886×1920、29.6秒（Git LFS） |

言語は20種類（ja en zh zh_TW ko es fr de pt ru it hi bn ar ur fa id tr vi th）。
ペルシャ語（fa）は App Store の言語一覧にないため、単独の言語としては提出できない。

### スクショ6枚の構成
1. `01_play` ピン抜き（g001）「広告で見たゲームが／本当に遊べる！」
2. `02_runner` 兵隊カウント（g018）のクリア画面「選んで増やせ！／その先は…？」
3. `03_rush` 広告ラッシュのプレイ画面（g063）
4. `04_3d` ペンギンすべり 3D（g104）のクリア画面「ドット絵も3Dも／全151本！」
5. `05_collection` 広告図鑑
6. `06_home` ホーム

画面は、各端末サイズで描画した本物のアプリのウィジェットを使っている。プレイ画面では、ゲームの表示領域だけを、同じゲームのコードでボットが実際にクリアした瞬間のフレームに描き替えている。進捗は撮影用の仮データ（151本すべて発見済み、コイン15100）。見出しは `tool/pv/store_copy.json` にある。

### 動画の仕様チェック（Apple App Preview 規定、2026-10-07 確認）
- 886×1920 縦、30fps、29.6秒（規定は15〜30秒）
- H.264 High Profile **Level 4.0**（規定は Level 4.0 まで。以前のものは 4.2 だったので作り直した）
- 映像は約10.3Mbps（規定の目標は 10〜12Mbps VBR）
- AAC ステレオ 48kHz、実測約270kbps（指定は256k。ffmpeg 標準の AAC エンコーダーだとこの程度上振れする）
- 1本37MB（上限は500MB）。**容量を絞る再エンコードは不要。ビットレートを10Mbps未満にすると規定外になる。**
- iPad 用のプレビュー動画（1200×1600）は作っていない（プレビュー動画自体は任意）。

### 前回の動画からの変更点
- スロット（g110、「大当たり777」）とコインプッシャー（g117）は、レーティング対策でギャンブル的な見た目をやめたので外した。代わりにフルーツ合体ドロップ（g008）とボウリング3D（g096）を入れた。どちらも最新のコードでボットが勝てることを scout で確認済み。
- エンドカードのロゴは `app_title` のブランド部分だけを使う（例: 「ひたすら広告　151の…」→「ひたすら広告」）。
- 効果音の間引き（151の連打バグ修正、クリア音を控えめに）は `make_pv.py` の `tame()` にある。

## 作り直し方（Windows）

前提: `../flutter`（D:\user\develop\flutter）、Python 3 + `numpy` `imageio-ffmpeg` `Pillow`、
`C:/Windows/Fonts` に Noto Sans JP/Arabic、Nirmala、Leelawadee UI、Malgun、MS YaHei/JhengHei。

```sh
# 必要なときだけ: ゲーム改修後、各クリップが今も勝てるか確認 → build/pv/scout.json
../flutter/bin/flutter test tool/pv/pv_scout_test.dart

# プレビュー動画（1言語およそ10分）。言語はカンマ区切り、または all
python tool/pv/make_pv.py ja
python tool/pv/make_pv.py ja --mix-only   # 映像は作り直さず、音だけ再ミックス

# スクショ（1言語・1端末およそ1分）
../flutter/bin/flutter test tool/pv/pv_render_test.dart --dart-define=PV_LANG=ja --dart-define=STORE_DEVICE=iphone_6_9
../flutter/bin/flutter test tool/pv/pv_render_test.dart --dart-define=PV_LANG=ja --dart-define=STORE_DEVICE=ipad_13

# build/ → store/app_store/ に書き出す（透過を除去、contact_sheet を作成、mp4 をコピー）
python tool/pv/export_store.py
```

主なファイル:
- `tool/pv/pv_render_test.dart`: 動画のタイムライン（`_montage`、`_rushPick`、`_gridNos`）と、スクショ撮影（`_storeMain`、`_storeCard`）
- `tool/pv/pv_bots.dart`: 自動プレイ用のボット。`tool/pv/pv_scout_test.dart`: どのボットとシードで勝てるかを探す
- `tool/pv/pv_script.json`: 動画のキャプション。`tool/pv/store_copy.json`: スクショの見出し
- `tool/pv/make_pv.py`: 描画 → x264 でエンコード → 効果音を間引いてミックス → mux

注意:
- **同じワークツリーで2つの描画を同時に走らせないこと。** `build/pv/<lang>/frames.rgba` を取り合って壊れる。
- 長い翻訳でレイアウトがはみ出すと、テストは失敗扱いになる（描画も止まる）。ロシア語・トルコ語で起きたホーム画面の2か所は `lib/ui/home.dart` で修正済み（このブランチに含む）。

## 未解決・メモ
- ホーム画面で、日本語の長いタイトルの改行位置が不格好（「151」が1行目の最後に残る）。アプリ側の表示なので、スクショ・動画にもそのまま出ている。
- アラビア語では、g073 の吹き出しが「!MPH」と表示される（その言語の訳がなく英語の文字列が使われ、右から左の並びで「!」が前に出る）。
- タイ語・インドネシア語の「AD RUSH」は、アプリ側で意図した訳語。
- `origin/codex/app-store-readiness-20261002` には、macOS のシミュレーターで実機スクショを撮るパイプラインが別にある。このブランチの素材は Flutter のテスト環境で描画したもので、実機のステータスバーは入っていない。
