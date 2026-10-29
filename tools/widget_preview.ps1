$ErrorPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Primitives

# Renders a preview of the Android home-screen widgets.
#
# The widget itself is drawn by Android from
# platform_overlay/android/app/src/main/res/layout/widget_*.xml. This
# script draws the same layout with the same colours, sizes and spacing
# so the design can be reviewed as an image, and checked against the XML
# whenever one of them changes.
#
#   tools/widget_preview.ps1  ->  tools/widget_preview.png

$out = Join-Path $PSScriptRoot 'widget_preview.png'

# dp -> px at 3x, the density most phones use.
$scale = 3.0
function Dp([double]$v) { return $v * $scale }

$brand = [System.Drawing.Color]::FromArgb(100, 239, 174)   # #64EFAE
$ink = [System.Drawing.Color]::White
$ink80 = [System.Drawing.Color]::FromArgb(230, 255, 255, 255)
$ink55 = [System.Drawing.Color]::FromArgb(138, 255, 255, 255)
$line = [System.Drawing.Color]::FromArgb(30, 58, 74)        # #1E3A4A
$top = [System.Drawing.Color]::FromArgb(11, 37, 52)         # #0B2534
$bottom = [System.Drawing.Color]::FromArgb(6, 22, 32)       # #061620

function Get-RoundedPath($x, $y, $w, $h, $r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($x, $y, $r, $r, 180, 90)
  $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
  $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
  $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
  $path.CloseFigure()
  return $path
}

function Draw-WidgetBackground($g, $x, $y, $w, $h) {
  $path = Get-RoundedPath $x $y $w $h (Dp 20)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point $x, $y),
    (New-Object System.Drawing.Point $x, ($y + $h)),
    $top, $bottom)
  $g.FillPath($brush, $path)
  $pen = New-Object System.Drawing.Pen $line, (Dp 1)
  $g.DrawPath($pen, $path)
  $pen.Dispose(); $brush.Dispose(); $path.Dispose()
}

# Mirrors an Android TextView: sans-serif, one line, ellipsis.
# -Align 'left' or 'right'; the box is $maxWidth wide starting at $x.
function Add-Text($g, $text, $x, $y, $sizeSp, $color, $bold, $maxWidth, $align = 'left') {
  $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  $font = New-Object System.Drawing.Font 'Roboto', ([float]$sizeSp * 0.75), $style, ([System.Drawing.GraphicsUnit]::Point)
  $brush = New-Object System.Drawing.SolidBrush $color
  # A new format every time: StringFormat.GenericTypographic is a shared
  # instance, and changing its alignment would leak into later calls.
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
  $fmt.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Near
  if ($align -eq 'right') {
    $fmt.Alignment = [System.Drawing.StringAlignment]::Far
  } else {
    $fmt.Alignment = [System.Drawing.StringAlignment]::Near
  }
  $size = $g.MeasureString($text, $font, [int]$maxWidth, $fmt)
  # The rectangle overload is the only one that honours alignment.
  $rect = New-Object System.Drawing.RectangleF ([float]$x), ([float]$y), ([float]$maxWidth), ([float]$size.Height + 6)
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $font.Dispose(); $brush.Dispose(); $fmt.Dispose()
  return $size.Height
}

function Add-Dot($g, $x, $y, $size, $color) {
  $brush = New-Object System.Drawing.SolidBrush $color
  $g.FillEllipse($brush, $x, $y, $size, $size)
  $brush.Dispose()
}

function Add-Sparkline($g, $x, $y, $w, $h, $color) {
  $points = @(0.0, 0.14, 0.06, 0.30, 0.24, 0.48, 0.40, 0.66, 0.60, 0.78, 0.72, 0.95)
  $n = $points.Count
  $pad = $h * 0.16
  $usable = $h - $pad * 2

  $line = New-Object System.Drawing.Drawing2D.GraphicsPath
  $area = New-Object System.Drawing.Drawing2D.GraphicsPath
  $prevX = 0
  $prevY = 0
  for ($i = 0; $i -lt $n; $i++) {
    $px = $x + ($w * $i / ($n - 1))
    $py = $y + $pad + $usable - ($usable * $points[$i])
    if ($i -eq 0) {
      $line.StartFigure()
      $line.AddLine($px, $py, $px, $py)
      $area.StartFigure()
      $area.AddLine($px, ($y + $h), $px, $py)
    } else {
      $line.AddLine($prevX, $prevY, $px, $py)
      $area.AddLine($prevX, $prevY, $px, $py)
    }
    $prevX = $px
    $prevY = $py
  }
  $area.AddLine($prevX, $prevY, ($x + $w), ($y + $h))
  $area.AddLine(($x + $w), ($y + $h), $x, ($y + $h))
  $area.CloseFigure()

  $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point $x, $y),
    (New-Object System.Drawing.Point $x, ($y + $h)),
    [System.Drawing.Color]::FromArgb(56, 100, 239, 174),
    [System.Drawing.Color]::FromArgb(0, 100, 239, 174))
  $g.FillPath($fill, $area)

  $pen = New-Object System.Drawing.Pen $color, (Dp 1.8)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
  $g.DrawPath($pen, $line)
  $pen.Dispose(); $fill.Dispose(); $area.Dispose(); $line.Dispose()
}

# ---------------------------------------------------------------------
# Portfolio widget
# ---------------------------------------------------------------------
function Draw-PortfolioWidget($g, $x, $y, $w, $h) {
  Draw-WidgetBackground $g $x $y $w $h
  $pad = Dp 12
  $cx = $x + $pad
  $cw = $w - 2 * $pad
  $right = $x + $w - $pad

  # Brand row: label on the left, holdings summary on the right.
  $labelH = Add-Text $g 'STOCK PULSE' ($cx + (Dp 6)) ($y + $pad) 9 $brand $true ($cw - (Dp 100))
  Add-Dot $g $cx ($y + $pad + ($labelH / 2) - (Dp 3)) (Dp 6) $brand
  Add-Text $g '8 holdings' ($right - (Dp 70)) ($y + $pad) 10 $ink55 $false (Dp 70) 'right'

  # Headline number with the day's change on the right.
  $valueY = $y + $pad + (Dp 15)
  Add-Text $g '$24,318.90' $cx $valueY 26 $ink $true ($cw - (Dp 104))
  Add-Text $g '+$120.50 (1.20%)' ($right - (Dp 100)) ($valueY + (Dp 11)) 12 $ink $true (Dp 100) 'right'

  # Trend line, filling the space between the number and the details.
  $sparkY = $valueY + (Dp 38)
  $sparkH = $h - $sparkY - (Dp 40)
  Add-Sparkline $g $cx $sparkY $cw $sparkH $brand

  # Hairline.
  $lineY = $y + $h - (Dp 38)
  $pen = New-Object System.Drawing.Pen $line, (Dp 1)
  $g.DrawLine($pen, $cx, $lineY, $right, $lineY)
  $pen.Dispose()

  # What is coming next.
  Add-Text $g 'Next dividend  RY.TO' $cx ($lineY + (Dp 9)) 11 $ink $true ($cw - (Dp 140))
  Add-Text $g '$0.85/share - in 9 days' ($right - (Dp 130)) ($lineY + (Dp 9)) 10 $brand $true (Dp 130) 'right'
}

# ---------------------------------------------------------------------
# Next dividend widget
# ---------------------------------------------------------------------
function Draw-DividendWidget($g, $x, $y, $w, $h) {
  Draw-WidgetBackground $g $x $y $w $h
  $pad = Dp 12
  $cx = $x + $pad
  $cw = $w - 2 * $pad
  $right = $x + $w - $pad

  $labelH = Add-Text $g 'NEXT DIVIDEND' ($cx + (Dp 6)) ($y + $pad) 9 $brand $true ($cw - (Dp 66))
  Add-Dot $g $cx ($y + $pad + ($labelH / 2) - (Dp 3)) (Dp 6) $brand
  Add-Text $g 'IN 9 DAYS' ($right - (Dp 64)) ($y + $pad) 9 $brand $true (Dp 64) 'right'

  Add-Text $g 'RY.TO' $cx ($y + $pad + (Dp 16)) 20 $ink $true $cw
  Add-Text $g '$0.85 /share' $cx ($y + $pad + (Dp 42)) 13 $brand $true $cw
  Add-Text $g 'Ex-dividend 5 Nov' $cx ($y + $pad + (Dp 62)) 10 $ink80 $false $cw

  $lineY = $y + $h - (Dp 30)
  $pen = New-Object System.Drawing.Pen $line, (Dp 1)
  $g.DrawLine($pen, $cx, $lineY, $right, $lineY)
  $pen.Dispose()

  Add-Text $g 'Paid 15 Nov' $cx ($lineY + (Dp 8)) 10 $ink55 $false $cw
}

# ---------------------------------------------------------------------
# Compose the sheet
# ---------------------------------------------------------------------
$gap = Dp 26
$pw = Dp 320
$ph = Dp 110
$dw = Dp 160
$dh = Dp 110
$margin = Dp 24

$width = [int]($margin * 2 + $pw + $gap + $dw)
$height = [int]($margin * 2 + $ph + (Dp 34))

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAlias'
$g.Clear([System.Drawing.Color]::FromArgb(18, 22, 26))

$label = [System.Drawing.Color]::FromArgb(140, 152, 164)
Add-Text $g 'PORTFOLIO WIDGET (4x2)' $margin (Dp 8) 9 $label $false 400
Draw-PortfolioWidget $g $margin (Dp 22) $pw $ph

Add-Text $g 'NEXT DIVIDEND WIDGET (2x2)' ($margin + $pw + $gap) (Dp 8) 9 $label $false 400
Draw-DividendWidget $g ($margin + $pw + $gap) (Dp 22) $dw $dh

$bitmap.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bitmap.Dispose()
Write-Host "Wrote $out"
