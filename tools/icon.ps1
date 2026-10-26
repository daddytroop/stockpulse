Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot '..\assets\icon'
function RoundRect($g, $rect, $radius, $brush) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $radius * 2
  $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
  $path.AddArc(($rect.Right - $d), $rect.Y, $d, $d, 270, 90)
  $path.AddArc(($rect.Right - $d), ($rect.Bottom - $d), $d, $d, 0, 90)
  $path.AddArc($rect.X, ($rect.Bottom - $d), $d, $d, 90, 90)
  $path.CloseFigure()
  $g.FillPath($brush, $path)
  $path.Dispose()
}

# 1024 launcher icon with a dark indigo-to-teal radial glow and rounded pulse.
$bmp = New-Object System.Drawing.Bitmap 1024, 1024
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$rect = New-Object System.Drawing.Rectangle 0, 0, 1024, 1024
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(6, 29, 43)), ([System.Drawing.Color]::FromArgb(3, 92, 77)), 55
$g.FillRectangle($bg, $rect)
$glow = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(26, 255, 214, 140)), ([System.Drawing.Color]::FromArgb(0)), 20
$g.FillRectangle($glow, $rect)
# Soft orbit ring.
$ringPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 255, 255, 255)), 18
$g.DrawEllipse($ringPen, 126, 126, 772, 772)
# Pulse shadow.
$line = @(
  (New-Object System.Drawing.Point 160, 650),
  (New-Object System.Drawing.Point 330, 470),
  (New-Object System.Drawing.Point 430, 650),
  (New-Object System.Drawing.Point 570, 350),
  (New-Object System.Drawing.Point 730, 610),
  (New-Object System.Drawing.Point 850, 310)
)
$shadowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(105, 0, 0, 0)), 118
$shadowPen.StartCap = 'Round'; $shadowPen.EndCap = 'Round'; $shadowPen.LineJoin = 'Round'
$g.DrawLines($shadowPen, @($line | ForEach-Object { New-Object System.Drawing.Point ($_.X + 10), ($_.Y + 18) }))
$mainPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 112
$mainPen.StartCap = 'Round'; $mainPen.EndCap = 'Round'; $mainPen.LineJoin = 'Round'
$g.DrawLines($mainPen, $line)
# Dividend coin and destination node.
$gold = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 202, 70))
$g.FillEllipse($gold, 142, 172, 166, 166)
$coinLine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 239, 155))
$g.FillEllipse($coinLine, 166, 194, 118, 118)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(222, 255, 255, 255))
$g.FillEllipse($white, 754, 214, 192, 192)
$mint = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(96, 218, 153))
$g.FillEllipse($mint, 786, 246, 128, 128)
$bmp.Save((Join-Path $out 'app_icon.png'), 'Png')

# Android 12 monochrome foreground: transparent canvas, white pulse only.
$fg = New-Object System.Drawing.Bitmap 1024, 1024
$fgg = [System.Drawing.Graphics]::FromImage($fg)
$fgg.SmoothingMode = 'AntiAlias'
$mono = @(
  (New-Object System.Drawing.Point 250, 620),
  (New-Object System.Drawing.Point 385, 480),
  (New-Object System.Drawing.Point 475, 620),
  (New-Object System.Drawing.Point 610, 370),
  (New-Object System.Drawing.Point 745, 390)
)
$monoPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 92
$monoPen.StartCap = 'Round'; $monoPen.EndCap = 'Round'; $monoPen.LineJoin = 'Round'
$fgg.DrawLines($monoPen, $mono)
$fgg.FillEllipse($white, 665, 260, 210, 210)
$fgg.FillEllipse($gold, 292, 262, 120, 120)
$fg.Save((Join-Path $out 'app_monochrome.png'), 'Png')

$g.Dispose(); $bmp.Dispose(); $fgg.Dispose(); $fg.Dispose()
Write-Host "Generated icon assets in $out"
