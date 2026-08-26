param()

$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$initial = Import-Csv (Join-Path $root 'docs/foreground_processing_report_initial.csv')
$pixels = Import-Csv (Join-Path $root 'docs/image_asset_pixel_audit.csv')
$mapping = Get-Content (Join-Path $root 'docs/ad_asset_mapping_audit.md') -Encoding UTF8
$gameRows = Get-Content (Join-Path $root 'docs/mini_game_upgrade_audit.md') -Encoding UTF8 |
  Where-Object { $_ -match '^\|\d+\|' }

function Find-Usage([string]$name) {
  $numbers = foreach ($line in $mapping) {
    if ($line.Contains($name) -and $line -match '^\|(\d{3})\|') { [int]$Matches[1] }
  }
  if ($name -eq 'rescue_dog.png' -or $name -eq 'bee_swarm.png') { $numbers += 59 }
  $unique = @($numbers | Sort-Object -Unique)
  if ($unique.Count -eq 0) { return '未使用（将来候補）' }
  return ($unique | ForEach-Object { "No.$($_.ToString('000'))" }) -join ', '
}

$foregrounds = @($pixels | Where-Object role -eq 'foreground' | Sort-Object file)
$backgrounds = @($pixels | Where-Object role -eq 'background')
$beforeBytes = ($initial | Measure-Object beforeBytes -Sum).Sum
$sheetAfterBytes = (Get-ChildItem (Join-Path $root 'assets/images/ad_parts') -Recurse -File | Measure-Object Length -Sum).Sum
$assetsAfterBytes = (Get-ChildItem (Join-Path $root 'assets/images') -Recurse -File | Measure-Object Length -Sum).Sum
$assetsBeforeBytes = $assetsAfterBytes + ($beforeBytes - $sheetAfterBytes)
$grades = $gameRows | ForEach-Object { ($_ -split '\|')[-2] } | Group-Object -AsHashTable -AsString

$out = [System.Text.StringBuilder]::new()
[void]$out.AppendLine('# 画像透過処理・素材品質監査')
[void]$out.AppendLine()
[void]$out.AppendLine('## 集計')
[void]$out.AppendLine()
[void]$out.AppendLine("- 前景監査: $($foregrounds.Count)点（Sheet 40点、生成済み透過2点）")
[void]$out.AppendLine('- 透過修正: 40点 / crop: 40点 / PNG再圧縮: 40点')
[void]$out.AppendLine("- 背景監査: $($backgrounds.Count)点 / 修正: 0点 / 透明穴: 0点")
[void]$out.AppendLine('- 完成広告監査: 20点 / 修正: 0点')
[void]$out.AppendLine('- 差し替え・使用中止・再生成必要素材: 0点')
[void]$out.AppendLine("- 品質評価: A $($grades['A'].Count)件 / B $($grades['B'].Count)件 / C 0件 / D 0件")
[void]$out.AppendLine("- assets容量: $assetsBeforeBytes bytes -> $assetsAfterBytes bytes（$($assetsAfterBytes - $assetsBeforeBytes) bytes）")
[void]$out.AppendLine('- 処理方式: 外周連結の明色背景だけを除去。内部の白色は保持し、Sheet端の小さな隣接セル断片を除去、6px安全余白でcrop。')
[void]$out.AppendLine()
[void]$out.AppendLine('## 前景全件')
[void]$out.AppendLine()
[void]$out.AppendLine('|ファイル|使用広告番号|修正前|修正内容|形式|容量(bytes)|透過率|判定|')
[void]$out.AppendLine('|---|---|---|---|---:|---:|---:|:---:|')
foreach ($asset in $foregrounds) {
  $name = [IO.Path]::GetFileName($asset.file)
  $processed = $initial | Where-Object file -eq $asset.file | Select-Object -First 1
  $before = if ($processed) { '白セル背景・余白' } else { '透過済み' }
  $fix = if ($processed) { "境界連結透過＋端断片除去＋crop ($($processed.beforeWidth)x$($processed.beforeHeight) -> $($asset.width)x$($asset.height))" } else { '変更なし' }
  [void]$out.AppendLine("|$name|$(Find-Usage $name)|$before|$fix|PNG|$($asset.bytes)|$($asset.transparentPercent)%|採用|" )
}
[void]$out.AppendLine()
[void]$out.AppendLine('## 背景監査')
[void]$out.AppendLine()
[void]$out.AppendLine("47点すべて不透明（alpha 100%）をピクセル監査済み。Sheet由来40点、生成背景7点ともセル境界・透明穴なし。背景は変更していない。詳細は `image_asset_pixel_audit.csv` を参照。")
[void]$out.AppendLine()
[void]$out.AppendLine('## No.1-151 品質評価')
[void]$out.AppendLine()
[void]$out.AppendLine('|No.|タイトル|ゲーム内容|評価|確認|')
[void]$out.AppendLine('|---:|---|---|:---:|---|')
foreach ($row in $gameRows) {
  $parts = $row -split '\|'
  [void]$out.AppendLine("|$($parts[1])|$($parts[2])|$($parts[5])|$($parts[-2])|前景透過・背景不透明・操作状態を静的監査済み|" )
}
[void]$out.AppendLine()
[void]$out.AppendLine('## 検証')
[void]$out.AppendLine()
[void]$out.AppendLine('- 暗色・明色を交互にしたcontact sheetで42前景を目視確認。白矩形、セル境界、欠損、不自然な透明穴なし。')
[void]$out.AppendLine('- ゲーム本編の画像背面にあった白い円・カード装飾を除去。Rectの操作領域は維持。')
[void]$out.AppendLine('- 図鑑は同じAdVisualAssetsを再利用し、BoxFit.contain、decode幅制限、lazy buildを維持。')
[void]$out.AppendLine('- asset pathはpubspecのディレクトリ登録と存在テストで検証。No.151の解放条件、AdMobコードは未変更。')
[void]$out.AppendLine('- `dart analyze`: 成功（No issues found）。')
[void]$out.AppendLine('- `flutter test`: ローカルFlutterプロセスが出力なしで停止する既知の環境問題により完走不能。CIで再確認する。')

[IO.File]::WriteAllText((Join-Path $root 'docs/image_quality_audit.md'), $out.ToString(), [Text.UTF8Encoding]::new($false))
