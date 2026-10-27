$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot '..\assets\icon'

# Match lib/widgets/pulse_logo.dart. Adaptive artwork fits Android's safe zone.
function Save-PulseIcon($name, $foreground, $monochrome) {
  $bitmap = New-Object System.Drawing.Bitmap 1024, 1024
  $g = [System.Drawing.Graphics]::FromImage($bitmap)
  $g.SmoothingMode = 'AntiAlias'
  if (!$foreground) { $g.Clear([System.Drawing.Color]::FromArgb(6, 29, 43)) }
  $extent = if ($foreground) { 620 } else { 840 }
  $offset = (1024 - $extent) / 2
  $g.TranslateTransform($offset, $offset)
  $g.ScaleTransform(($extent / 100), ($extent / 100))
  $color = if ($monochrome) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(100, 239, 174) }
  $pen = New-Object System.Drawing.Pen $color, 7
  $pen.StartCap = 'Round'
  $pen.EndCap = 'Round'
  $pen.LineJoin = 'Round'
  $g.DrawArc($pen, 10, 10, 80, 80, [single](0.08 * 180 / [Math]::PI), [single](1.71 * 180))
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddLine(12, 59, 29, 59)
  $path.AddBezier(29, 59, 35, 59, 39, 44, 45, 44)
  $path.AddBezier(45, 44, 50, 44, 54, 61, 60, 61)
  $path.AddLine(60, 61, 87, 33)
  $g.DrawPath($pen, $path)
  $arrow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $arrow.AddLine(74, 35, 88, 31)
  $arrow.AddLine(88, 31, 88, 46)
  $g.DrawPath($pen, $arrow)
  $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $arrow.Dispose()
  $path.Dispose()
  $pen.Dispose()
  $g.Dispose()
  $bitmap.Dispose()
}

Save-PulseIcon 'app_icon.png' $false $false
Save-PulseIcon 'app_icon_foreground.png' $true $false
Save-PulseIcon 'app_monochrome.png' $true $true
