# Иконки отладочных сборок «IronRise DEV»: обычная иконка + оранжевая плашка DEV.
# Кладёт их в ресурсы debug (телефон и часы), бета остаётся с обычной иконкой.
# Запуск: powershell -ExecutionPolicy Bypass -File tools\make-dev-icons.ps1
Add-Type -AssemblyName System.Drawing
$Repo = Split-Path -Parent $PSScriptRoot
$Orange = [System.Drawing.Color]::FromArgb(255, 255, 122, 61)

# Плашка DEV: прямоугольник со скруглением, ширина и положение — доли картинки.
function Add-DevBadge([string]$src, [string]$dst, [double]$top, [double]$width, [double]$height) {
  $img = [System.Drawing.Bitmap]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
  $w = $img.Width * $width
  $h = $img.Height * $height
  $x = ($img.Width - $w) / 2
  $y = $img.Height * $top
  $r = $h / 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($x, $y, 2 * $r, 2 * $r, 90, 180)
  $path.AddArc($x + $w - 2 * $r, $y, 2 * $r, 2 * $r, 270, 180)
  $path.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush $Orange), $path)
  $font = New-Object System.Drawing.Font 'Arial', ([float]($h * 0.62)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'
  $fmt.LineAlignment = 'Center'
  $rect = New-Object System.Drawing.RectangleF $x, ([float]($y + $h * 0.04)), $w, $h
  $g.DrawString('DEV', $font, [System.Drawing.Brushes]::White, $rect, $fmt)
  $g.Dispose()
  $img.Dispose()
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$densities = 'mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'

# Телефон: старая иконка и передний слой адаптивной.
$phone = Join-Path $Repo 'app\android\app\src'
foreach ($d in $densities) {
  Add-DevBadge "$phone\main\res\mipmap-$d\ic_launcher.png" "$phone\debug\res\mipmap-$d\ic_launcher.png" 0.66 0.78 0.24
  Add-DevBadge "$phone\main\res\drawable-$d\ic_launcher_foreground.png" "$phone\debug\res\drawable-$d\ic_launcher_foreground.png" 0.62 0.66 0.22
}

# Часы: иконка круглая — плашка ниже центра, уже.
$watch = Join-Path $Repo 'watch\wearos\app\src'
foreach ($d in $densities) {
  Add-DevBadge "$watch\main\res\mipmap-$d\ic_launcher.png" "$watch\debug\res\mipmap-$d\ic_launcher.png" 0.64 0.66 0.24
}
Write-Host 'Готово: иконки DEV в src/debug/res телефона и часов'
