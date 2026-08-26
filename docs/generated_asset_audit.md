# 追加生成アセット監査

指示書②に基づき、既存Sheet監査で不足していた再利用性の高い素材だけを追加した。単純図形、ピン、水流、ゲート類はコード描画を継続する。

## 採用アセット

|ファイル|種別|寸法|形式|容量|透過|使用広告|
|---|---|---:|---|---:|---|---|
|`characters/rescue_dog.png`|前景|409x448|PNG|283,946 bytes|あり|No.059|
|`game/bee_swarm.png`|前景|448x409|PNG|255,577 bytes|あり|No.059|
|`backgrounds/palace_treasure_hall.jpg`|背景|960x720|JPEG|104,022 bytes|なし|No.031-040|
|`backgrounds/stone_dungeon.jpg`|背景|960x720|JPEG|81,433 bytes|なし|No.041-045|
|`backgrounds/sunny_grassland.jpg`|背景|960x720|JPEG|106,305 bytes|なし|No.059|
|`backgrounds/parking_lot.jpg`|背景|960x720|JPEG|94,382 bytes|なし|No.061-062|
|`backgrounds/dirty_room.jpg`|背景|960x720|JPEG|97,233 bytes|なし|No.066, 068, 070, 072, 074|
|`backgrounds/renovated_room.jpg`|背景|960x720|JPEG|97,416 bytes|なし|No.067, 069, 071, 073, 075|
|`backgrounds/delivery_warehouse.jpg`|背景|960x720|JPEG|119,300 bytes|なし|No.093-100, 123|

全パスの起点は `assets/images/generated/`。前景は四隅のalphaが0、背景は四隅のalphaが255であることを機械検査した。追加アセットに500KB超・1MB超のファイルはない。

## 生成後に不採用とした候補

- 俯瞰の赤い車: 背景除去の再編集後も暗色背景が残ったため不採用。No.061-062は既存のゲーム描画と駐車場背景を使用する。
- 空のコップ: 透過を示す市松模様が画像へ焼き込まれたため不採用。No.058は既存のゲーム描画を使用する。

不採用候補はプロジェクトへコピーしておらず、未使用生成画像としてアプリ容量へ含めていない。

## 容量

- 追加前の `assets/images/`: 100ファイル、14,721,556 bytes
- 追加分: 9ファイル、1,239,614 bytes
- 追加後: 109ファイル、15,961,170 bytes
- 増加率: 約8.42%

## 残る不足

- No.001-003, 010: レトロWeb用カーソル・バナー部品
- No.058: 透明なコップと水流。現状はコード描画で成立
- No.061-062: 透過の俯瞰車。現状はコード描画と専用背景で成立
- No.131, 133, 137-140, 149: 広告メタ表現用の汎用バナー部品

既存IP、企業ロゴ、文字、価格、数字を含む画像は生成していない。

## 検証結果

- 画像の存在数、寸法、容量、四隅alpha、500KB/1MB超過をPowerShellとSystem.Drawingで検査済み
- `git diff --check`: 問題なし
- `flutter test` / `flutter analyze`: Flutter SDKのDart子プロセスが無出力のまま終了しない環境問題が発生したため、この変更後の完走結果は未取得
- 変更前の直近検証では全32テスト、`flutter analyze`、Webビルドが成功済み
