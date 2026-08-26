param(
  [switch]$CreateContactSheets
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$foregroundDirs = @(
  (Join-Path $root 'assets/images/ad_parts'),
  (Join-Path $root 'assets/images/generated/characters'),
  (Join-Path $root 'assets/images/generated/game')
)
$backgroundDirs = @(
  (Join-Path $root 'assets/images/ad_backgrounds'),
  (Join-Path $root 'assets/images/generated/backgrounds')
)

function Measure-Image([System.IO.FileInfo]$file, [string]$role) {
  $bitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
  try {
    $transparent = 0
    $partial = 0
    $opaque = 0
    $minX = $bitmap.Width
    $minY = $bitmap.Height
    $maxX = -1
    $maxY = -1
    $cornerWhite = 0
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
      for ($x = 0; $x -lt $bitmap.Width; $x++) {
        $pixel = $bitmap.GetPixel($x, $y)
        if ($pixel.A -eq 0) { $transparent++ }
        elseif ($pixel.A -lt 255) { $partial++ }
        else { $opaque++ }
        if ($pixel.A -gt 8) {
          if ($x -lt $minX) { $minX = $x }
          if ($y -lt $minY) { $minY = $y }
          if ($x -gt $maxX) { $maxX = $x }
          if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }
    $right = $bitmap.Width - 1
    $bottom = $bitmap.Height - 1
    foreach ($point in @(@(0,0), @($right,0), @(0,$bottom), @($right,$bottom))) {
      $p = $bitmap.GetPixel($point[0], $point[1])
      if ($p.R -ge 245 -and $p.G -ge 245 -and $p.B -ge 245) { $cornerWhite++ }
    }
    $pixels = $bitmap.Width * $bitmap.Height
    [pscustomobject]@{
      file = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
      role = $role
      width = $bitmap.Width
      height = $bitmap.Height
      bytes = $file.Length
      transparentPercent = [math]::Round($transparent * 100.0 / $pixels, 2)
      partialPercent = [math]::Round($partial * 100.0 / $pixels, 2)
      opaquePercent = [math]::Round($opaque * 100.0 / $pixels, 2)
      whiteCorners = $cornerWhite
      contentBounds = if ($maxX -lt 0) { 'empty' } else { "$minX,$minY,$maxX,$maxY" }
    }
  }
  finally { $bitmap.Dispose() }
}

$rows = @()
foreach ($dir in $foregroundDirs) {
  if (Test-Path $dir) {
    $rows += Get-ChildItem $dir -Recurse -File -Include *.png,*.jpg,*.jpeg | ForEach-Object { Measure-Image $_ 'foreground' }
  }
}
foreach ($dir in $backgroundDirs) {
  if (Test-Path $dir) {
    $rows += Get-ChildItem $dir -Recurse -File -Include *.png,*.jpg,*.jpeg | ForEach-Object { Measure-Image $_ 'background' }
  }
}

$reportPath = Join-Path $root 'docs/image_asset_pixel_audit.csv'
$rows | Sort-Object role,file | Export-Csv $reportPath -NoTypeInformation -Encoding utf8

if ($CreateContactSheets) {
  $foregrounds = @($rows | Where-Object role -eq 'foreground')
  $cellW = 180
  $cellH = 165
  $columns = 6
  $sheet = New-Object System.Drawing.Bitmap ($cellW * $columns), ($cellH * [math]::Ceiling($foregrounds.Count / $columns))
  $graphics = [System.Drawing.Graphics]::FromImage($sheet)
  try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(35, 40, 48))
    $font = New-Object System.Drawing.Font 'Arial', 8
    for ($i = 0; $i -lt $foregrounds.Count; $i++) {
      $x = ($i % $columns) * $cellW
      $y = [math]::Floor($i / $columns) * $cellH
      $brush = if (($i % 2) -eq 0) { [System.Drawing.Brushes]::DarkSlateGray } else { [System.Drawing.Brushes]::LightSteelBlue }
      $graphics.FillRectangle($brush, $x, $y, $cellW, $cellH)
      $path = Join-Path $root $foregrounds[$i].file
      $image = [System.Drawing.Image]::FromFile($path)
      try { $graphics.DrawImage($image, $x + 10, $y + 8, $cellW - 20, $cellH - 32) }
      finally { $image.Dispose() }
      $graphics.DrawString([IO.Path]::GetFileName($foregrounds[$i].file), $font, [System.Drawing.Brushes]::White, $x + 4, $y + $cellH - 21)
    }
    $sheet.Save((Join-Path $root 'docs/foreground_contact_sheet.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $font.Dispose()
  }
  finally { $graphics.Dispose(); $sheet.Dispose() }
}

$rows | Group-Object role | ForEach-Object {
  [pscustomobject]@{
    role = $_.Name
    count = $_.Count
    bytes = ($_.Group | Measure-Object bytes -Sum).Sum
    withTransparency = @($_.Group | Where-Object transparentPercent -gt 0).Count
    whiteCornerCandidates = @($_.Group | Where-Object whiteCorners -ge 3).Count
  }
} | Format-Table -AutoSize
