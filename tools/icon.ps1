$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Generates the launcher / splash artwork from the same geometry as
# lib/widgets/pulse_logo.dart so the icon on the home screen is the same
# picture as the icon inside the app.
#
#   * app_icon.png            - full tile (background + mark), legacy icon
#   * app_icon_foreground.png - mark only, transparent, for adaptive icons
#   * app_monochrome.png      - mark only in white, for themed icons

$out = Join-Path $PSScriptRoot '..\assets\icon'
$background = [System.Drawing.Color]::FromArgb(6, 29, 43)   # #061D2B
$mark = [System.Drawing.Color]::FromArgb(100, 239, 174)      # #64EFAE
$markWhite = [System.Drawing.Color]::White

# The mark is drawn in a 100x100 space, exactly as the Flutter painter does.
# The gap in the orbit is at the top right, where the arrow points.
function Save-PulseIcon($name, $includeBackground, $strokeColor) {
  $bitmap = New-Object System.Drawing.Bitmap 1024, 1024
  $g = [System.Drawing.Graphics]::FromImage($bitmap)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)

  if ($includeBackground) {
    $radius = 1024 * 0.22
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc(1024 - $d, 0, $d, $d, 270, 90)
    $path.AddArc(1024 - $d, 1024 - $d, $d, $d, 0, 90)
    $path.AddArc(0, 1024 - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $background), $path)
    $path.Dispose()
  }

  # Adaptive foreground artwork is scaled to 62% and centred so it lands in
  # the safe zone Android expects.
  $extent = 1024 * 0.62
  $offset = (1024 - $extent) / 2
  $g.TranslateTransform($offset, $offset)
  $g.ScaleTransform(($extent / 100), ($extent / 100))

  $pen = New-Object System.Drawing.Pen $strokeColor, 7
  $pen.StartCap = 'Round'
  $pen.EndCap = 'Round'
  $pen.LineJoin = 'Round'

  # Open orbit: starts just after 3 o'clock and sweeps 1.71 * pi.
  $g.DrawArc($pen, 10, 10, 80, 80, 4.58, 307.8)

  $pulse = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pulse.AddLine(12, 59, 29, 59)
  $pulse.AddBezier(29, 59, 35, 59, 39, 44, 45, 44)
  $pulse.AddBezier(45, 44, 50, 44, 54, 61, 60, 61)
  $pulse.AddLine(60, 61, 87, 33)
  $g.DrawPath($pen, $pulse)

  $arrow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $arrow.AddLine(74, 35, 88, 31)
  $arrow.AddLine(88, 31, 88, 46)
  $g.DrawPath($pen, $arrow)

  $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $arrow.Dispose()
  $pulse.Dispose()
  $pen.Dispose()
  $g.Dispose()
  $bitmap.Dispose()
}

Save-PulseIcon 'app_icon.png' $true $mark
Save-PulseIcon 'app_icon_foreground.png' $false $mark
Save-PulseIcon 'app_monochrome.png' $false $markWhite
