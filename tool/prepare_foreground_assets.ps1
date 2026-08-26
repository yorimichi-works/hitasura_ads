param([int]$Padding = 6)

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public sealed class ForegroundResult {
  public int BeforeWidth, BeforeHeight, AfterWidth, AfterHeight, RemovedPixels;
}

public static class ForegroundProcessor {
  static bool IsBackground(int argb) {
    int a = (argb >> 24) & 255, r = (argb >> 16) & 255;
    int g = (argb >> 8) & 255, b = argb & 255;
    if (a == 0) return true;
    int min = Math.Min(r, Math.Min(g, b));
    int max = Math.Max(r, Math.Max(g, b));
    return min >= 225 && max - min <= 38;
  }

  public static ForegroundResult Convert(string path, int padding) {
    using (var stream = new MemoryStream(File.ReadAllBytes(path)))
    using (var source = new Bitmap(stream)) {
      int width = source.Width, height = source.Height, count = width * height;
      var rect = new Rectangle(0, 0, width, height);
      var data = source.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var pixels = new int[count];
      Marshal.Copy(data.Scan0, pixels, 0, count);
      source.UnlockBits(data);

      var visited = new bool[count];
      var queue = new Queue<int>(width * 2 + height * 2);
      for (int x = 0; x < width; x++) { queue.Enqueue(x); queue.Enqueue((height - 1) * width + x); }
      for (int y = 1; y < height - 1; y++) { queue.Enqueue(y * width); queue.Enqueue(y * width + width - 1); }
      while (queue.Count > 0) {
        int index = queue.Dequeue();
        if (visited[index]) continue;
        visited[index] = true;
        if (!IsBackground(pixels[index])) continue;
        int x = index % width, y = index / width;
        if (x > 0) queue.Enqueue(index - 1);
        if (x + 1 < width) queue.Enqueue(index + 1);
        if (y > 0) queue.Enqueue(index - width);
        if (y + 1 < height) queue.Enqueue(index + width);
      }

      int minX = width, minY = height, maxX = -1, maxY = -1, removed = 0;
      for (int i = 0; i < count; i++) {
        if (visited[i] && IsBackground(pixels[i])) { pixels[i] = 0; removed++; continue; }
      }

      // Sheet slicing can leave a thin disconnected sliver from the adjacent cell.
      // Remove only small components that still touch the original cell boundary.
      var componentVisited = new bool[count];
      for (int start = 0; start < count; start++) {
        if (componentVisited[start] || ((pixels[start] >> 24) & 255) <= 8) continue;
        var component = new List<int>();
        var componentQueue = new Queue<int>();
        componentQueue.Enqueue(start);
        componentVisited[start] = true;
        int componentMinX = width, componentMinY = height, componentMaxX = -1, componentMaxY = -1;
        bool touchesEdge = false;
        while (componentQueue.Count > 0) {
          int index = componentQueue.Dequeue();
          component.Add(index);
          int x = index % width, y = index / width;
          componentMinX = Math.Min(componentMinX, x); componentMinY = Math.Min(componentMinY, y);
          componentMaxX = Math.Max(componentMaxX, x); componentMaxY = Math.Max(componentMaxY, y);
          if (x == 0 || y == 0 || x == width - 1 || y == height - 1) touchesEdge = true;
          int[] neighbors = { index - 1, index + 1, index - width, index + width };
          foreach (int next in neighbors) {
            if (next < 0 || next >= count || componentVisited[next]) continue;
            int nx = next % width, ny = next / width;
            if (Math.Abs(nx - x) + Math.Abs(ny - y) != 1) continue;
            if (((pixels[next] >> 24) & 255) <= 8) continue;
            componentVisited[next] = true;
            componentQueue.Enqueue(next);
          }
        }
        int componentWidth = componentMaxX - componentMinX + 1;
        int componentHeight = componentMaxY - componentMinY + 1;
        if (touchesEdge && (component.Count < 5000 || componentWidth <= 24 || componentHeight <= 24)) {
          foreach (int index in component) pixels[index] = 0;
          removed += component.Count;
        }
      }

      for (int i = 0; i < count; i++) {
        if (((pixels[i] >> 24) & 255) > 8) {
          int x = i % width, y = i / width;
          minX = Math.Min(minX, x); minY = Math.Min(minY, y);
          maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
        }
      }
      if (maxX < 0) throw new InvalidDataException("Background removal produced an empty image: " + path);

      using (var output = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
        var outputData = output.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(pixels, 0, outputData.Scan0, count);
        output.UnlockBits(outputData);
        int left = Math.Max(0, minX - padding), top = Math.Max(0, minY - padding);
        int right = Math.Min(width - 1, maxX + padding), bottom = Math.Min(height - 1, maxY + padding);
        int cropWidth = right - left + 1, cropHeight = bottom - top + 1;
        using (var cropped = output.Clone(new Rectangle(left, top, cropWidth, cropHeight), PixelFormat.Format32bppArgb)) {
          string temporary = path + ".tmp.png";
          cropped.Save(temporary, ImageFormat.Png);
          File.Delete(path);
          File.Move(temporary, path);
        }
        return new ForegroundResult { BeforeWidth = width, BeforeHeight = height,
          AfterWidth = cropWidth, AfterHeight = cropHeight, RemovedPixels = removed };
      }
    }
  }
}
'@ -ReferencedAssemblies System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $root 'assets/images/ad_parts'
$files = Get-ChildItem $sourceRoot -Recurse -File -Filter '*.png' |
  Where-Object Name -Match '^sheet[12]_\d{2}\.png$' |
  Sort-Object FullName
$rows = foreach ($file in $files) {
  $beforeBytes = $file.Length
  $result = [ForegroundProcessor]::Convert($file.FullName, $Padding)
  $updated = Get-Item $file.FullName
  [pscustomobject]@{
    file = $updated.FullName.Substring($root.Length + 1).Replace('\', '/')
    beforeWidth = $result.BeforeWidth; beforeHeight = $result.BeforeHeight
    afterWidth = $result.AfterWidth; afterHeight = $result.AfterHeight
    removedPixels = $result.RemovedPixels
    removedPercent = [math]::Round($result.RemovedPixels * 100.0 / ($result.BeforeWidth * $result.BeforeHeight), 2)
    beforeBytes = $beforeBytes; afterBytes = $updated.Length
  }
}
$rows | Export-Csv (Join-Path $root 'docs/foreground_processing_report.csv') -NoTypeInformation -Encoding utf8
$rows | Format-Table file, beforeWidth, beforeHeight, afterWidth, afterHeight, removedPercent -AutoSize
