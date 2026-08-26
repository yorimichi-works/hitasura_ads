param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDirectory,
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sheetDefinitions = @(
  @{ Number = 1; Type = 'adPart'; Directory = 'assets/images/ad_parts/sheet1' },
  @{ Number = 2; Type = 'adPart'; Directory = 'assets/images/ad_parts/sheet2' },
  @{ Number = 3; Type = 'completeAd'; Directory = 'assets/images/complete_ads/sheet3' },
  @{ Number = 4; Type = 'background'; Directory = 'assets/images/ad_backgrounds/sheet4' },
  @{ Number = 5; Type = 'background'; Directory = 'assets/images/ad_backgrounds/sheet5' }
)

$catalog = [System.Collections.Generic.List[object]]::new()

foreach ($definition in $sheetDefinitions) {
  $sheetNumber = $definition.Number
  $sourcePath = Join-Path $SourceDirectory "sheet$sheetNumber.jpeg"
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source sheet not found: $sourcePath"
  }

  $outputDirectory = Join-Path $ProjectRoot $definition.Directory
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
  Get-ChildItem -LiteralPath $outputDirectory -Filter "sheet${sheetNumber}_*.png" |
    Remove-Item -Force

  $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
  try {
    for ($row = 0; $row -lt 4; $row++) {
      $top = [Math]::Round($row * $source.Height / 4)
      $bottom = [Math]::Round(($row + 1) * $source.Height / 4)

      for ($column = 0; $column -lt 5; $column++) {
        $left = [Math]::Round($column * $source.Width / 5)
        $right = [Math]::Round(($column + 1) * $source.Width / 5)
        $index = ($row * 5) + $column + 1
        $fileName = 'sheet{0}_{1:D2}.png' -f $sheetNumber, $index
        $relativePath = ($definition.Directory + '/' + $fileName).Replace('\', '/')
        $rectangle = [System.Drawing.Rectangle]::new(
          $left,
          $top,
          $right - $left,
          $bottom - $top
        )
        $cell = $source.Clone($rectangle, $source.PixelFormat)
        try {
          $cell.Save(
            (Join-Path $outputDirectory $fileName),
            [System.Drawing.Imaging.ImageFormat]::Png
          )
        }
        finally {
          $cell.Dispose()
        }

        $catalog.Add([ordered]@{
          id = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
          type = $definition.Type
          assetPath = $relativePath
          sheet = $sheetNumber
          index = $index
          row = $row + 1
          column = $column + 1
          width = $right - $left
          height = $bottom - $top
        })
      }
    }
  }
  finally {
    $source.Dispose()
  }
}

$catalogPath = Join-Path $ProjectRoot 'assets/data/image_asset_catalog.json'
$catalogJson = $catalog | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText(
  $catalogPath,
  $catalogJson,
  [System.Text.UTF8Encoding]::new($false)
)
Write-Host "Created $($catalog.Count) image assets and $catalogPath"
