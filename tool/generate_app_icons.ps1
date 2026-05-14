$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$logoPath = Join-Path $projectRoot 'assets\naham_logo.png'
$namePath = Join-Path $projectRoot 'assets\naham_name.png'
$masterPath = Join-Path $projectRoot 'assets\app_icon_master.png'
$backgroundMasterPath = Join-Path $projectRoot 'assets\app_icon_background.png'
$foregroundMasterPath = Join-Path $projectRoot 'assets\app_icon_foreground.png'

function New-Color([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function Initialize-Graphics([System.Drawing.Graphics]$graphics) {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
}

function Draw-Background([System.Drawing.Graphics]$graphics, [int]$size) {
    $green = New-Color 148 190 141
    $greenAccent = New-Color 168 208 160
    $purple = New-Color 154 129 204
    $purpleAccent = New-Color 132 108 184

    $topWaveBase = 182
    $bottomWaveBase = 814
    $waveAmplitude = 30
    $waveLength = 142
    $waveStep = 6

    function Get-WaveY([int]$x, [double]$base, [double]$phase = 0) {
        return $base + [Math]::Sin((($x / $waveLength) * [Math]::PI * 2) + $phase) * $waveAmplitude
    }

    $topPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $topPath.StartFigure()
    $topPath.AddLine(0, 0, $size, 0)
    $topPath.AddLine($size, 0, $size, (Get-WaveY $size $topWaveBase 0))
    for ($x = $size; $x -ge 0; $x -= $waveStep) {
        $topPath.AddLine(
            [float]$x,
            [float](Get-WaveY $x $topWaveBase 0),
            [float]($x - $waveStep),
            [float](Get-WaveY ($x - $waveStep) $topWaveBase 0)
        )
    }
    $topPath.CloseFigure()

    $middlePath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $middlePath.StartFigure()
    $middlePath.AddLine(0, (Get-WaveY 0 $topWaveBase 0), 0, (Get-WaveY 0 $bottomWaveBase ([Math]::PI)))
    for ($x = 0; $x -le $size; $x += $waveStep) {
        $middlePath.AddLine(
            [float]$x,
            [float](Get-WaveY $x $bottomWaveBase ([Math]::PI)),
            [float]($x + $waveStep),
            [float](Get-WaveY ($x + $waveStep) $bottomWaveBase ([Math]::PI))
        )
    }
    $middlePath.AddLine($size, (Get-WaveY $size $bottomWaveBase ([Math]::PI)), $size, (Get-WaveY $size $topWaveBase 0))
    for ($x = $size; $x -ge 0; $x -= $waveStep) {
        $middlePath.AddLine(
            [float]$x,
            [float](Get-WaveY $x $topWaveBase 0),
            [float]($x - $waveStep),
            [float](Get-WaveY ($x - $waveStep) $topWaveBase 0)
        )
    }
    $middlePath.CloseFigure()

    $bottomPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bottomPath.StartFigure()
    $bottomPath.AddLine(0, $size, $size, $size)
    $bottomPath.AddLine($size, $size, $size, (Get-WaveY $size $bottomWaveBase ([Math]::PI)))
    for ($x = $size; $x -ge 0; $x -= $waveStep) {
        $bottomPath.AddLine(
            [float]$x,
            [float](Get-WaveY $x $bottomWaveBase ([Math]::PI)),
            [float]($x - $waveStep),
            [float](Get-WaveY ($x - $waveStep) $bottomWaveBase ([Math]::PI))
        )
    }
    $bottomPath.CloseFigure()

    $topBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        ([System.Drawing.Point]::new(0, 0)),
        ([System.Drawing.Point]::new(0, $topWaveBase)),
        $purple,
        $purpleAccent
    )
    $graphics.FillPath($topBrush, $topPath)

    $middleBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        ([System.Drawing.Point]::new(0, $topWaveBase)),
        ([System.Drawing.Point]::new(0, $bottomWaveBase)),
        $greenAccent,
        $green
    )
    $graphics.FillPath($middleBrush, $middlePath)

    $bottomBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        ([System.Drawing.Point]::new(0, $bottomWaveBase)),
        ([System.Drawing.Point]::new(0, $size)),
        $purple,
        $purpleAccent
    )
    $graphics.FillPath($bottomBrush, $bottomPath)

    $wavePen = New-Object System.Drawing.Pen((New-Color 255 255 255 108), 10)
    $wavePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $topWavePoints = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $bottomWavePoints = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($x = 0; $x -le $size; $x += $waveStep) {
        $topWavePoints.Add([System.Drawing.PointF]::new([float]$x, [float](Get-WaveY $x $topWaveBase 0)))
        $bottomWavePoints.Add([System.Drawing.PointF]::new([float]$x, [float](Get-WaveY $x $bottomWaveBase ([Math]::PI))))
    }
    $graphics.DrawCurve($wavePen, $topWavePoints.ToArray(), 0.45)
    $graphics.DrawCurve($wavePen, $bottomWavePoints.ToArray(), 0.45)

    $highlightBrush = New-Object System.Drawing.SolidBrush((New-Color 255 255 255 22))
    $graphics.FillEllipse($highlightBrush, 48, 36, 330, 128)
    $graphics.FillEllipse($highlightBrush, 650, 862, 286, 110)

    $highlightBrush.Dispose()
    $topBrush.Dispose()
    $middleBrush.Dispose()
    $bottomBrush.Dispose()
    $wavePen.Dispose()
    $topPath.Dispose()
    $middlePath.Dispose()
    $bottomPath.Dispose()
}

function Draw-Brand(
    [System.Drawing.Graphics]$graphics,
    [int]$canvasSize,
    [int]$logoWidth,
    [int]$logoY,
    [int]$nameWidth,
    [int]$nameY
) {
    $logoImage = [System.Drawing.Image]::FromFile($logoPath)

    $logoHeight = [int]([double]$logoImage.Height / $logoImage.Width * $logoWidth)
    $logoX = [int](($canvasSize - $logoWidth) / 2)
    $graphics.DrawImage($logoImage, $logoX, $logoY, $logoWidth, $logoHeight)

    if ($nameWidth -gt 0) {
        $nameImage = [System.Drawing.Image]::FromFile($namePath)
        $nameHeight = [int]([double]$nameImage.Height / $nameImage.Width * $nameWidth)
        $nameX = [int](($canvasSize - $nameWidth) / 2)
        $graphics.DrawImage($nameImage, $nameX, $nameY, $nameWidth, $nameHeight)
        $nameImage.Dispose()
    }

    $logoImage.Dispose()
}

function Save-Bitmap([System.Drawing.Bitmap]$bitmap, [string]$destination) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Draw-MasterIcon {
    $size = 1024
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    Initialize-Graphics $graphics
    $graphics.Clear([System.Drawing.Color]::Transparent)

    Draw-Background -graphics $graphics -size $size
    Draw-Brand -graphics $graphics -canvasSize $size -logoWidth 610 -logoY 118 -nameWidth 0 -nameY 0

    $graphics.Dispose()
    Save-Bitmap -bitmap $bitmap -destination $masterPath
    $bitmap.Dispose()
}

function Draw-AdaptiveBackground {
    $size = 1024
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    Initialize-Graphics $graphics
    $graphics.Clear([System.Drawing.Color]::Transparent)

    Draw-Background -graphics $graphics -size $size

    $graphics.Dispose()
    Save-Bitmap -bitmap $bitmap -destination $backgroundMasterPath
    $bitmap.Dispose()
}

function Draw-AdaptiveForeground {
    $size = 1024
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    Initialize-Graphics $graphics
    $graphics.Clear([System.Drawing.Color]::Transparent)

    Draw-Brand -graphics $graphics -canvasSize $size -logoWidth 620 -logoY 232 -nameWidth 0 -nameY 0

    $graphics.Dispose()
    Save-Bitmap -bitmap $bitmap -destination $foregroundMasterPath
    $bitmap.Dispose()
}

function Save-PngIcon([string]$sourcePath, [string]$destination, [int]$size) {
    $source = [System.Drawing.Image]::FromFile($sourcePath)
    $target = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    Initialize-Graphics $graphics
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($source, 0, 0, $size, $size)
    $graphics.Dispose()
    $source.Dispose()
    Save-Bitmap -bitmap $target -destination $destination
    $target.Dispose()
}

function Save-WindowsIcon([string]$destination) {
    $source = [System.Drawing.Image]::FromFile($masterPath)
    $bitmap = New-Object System.Drawing.Bitmap 256, 256
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    Initialize-Graphics $graphics
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($source, 0, 0, 256, 256)
    $graphics.Dispose()
    $source.Dispose()

    $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $stream = [System.IO.File]::Create($destination)
    $icon.Save($stream)
    $stream.Dispose()
    $icon.Dispose()
    $bitmap.Dispose()
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $masterPath) | Out-Null
Draw-MasterIcon
Draw-AdaptiveBackground
Draw-AdaptiveForeground

$pngTargets = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png' = 16
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png' = 32
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png' = 64
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png' = 128
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png' = 256
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png' = 512
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png' = 1024
    'web\favicon.png' = 64
    'web\icons\Icon-192.png' = 192
    'web\icons\Icon-512.png' = 512
    'web\icons\Icon-maskable-192.png' = 192
    'web\icons\Icon-maskable-512.png' = 512
}

foreach ($entry in $pngTargets.GetEnumerator()) {
    $fullPath = Join-Path $projectRoot $entry.Key
    Save-PngIcon -sourcePath $masterPath -destination $fullPath -size $entry.Value
}

$adaptiveAndroidTargets = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher_background.png' = 108
    'android\app\src\main\res\mipmap-hdpi\ic_launcher_background.png' = 162
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher_background.png' = 216
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher_background.png' = 324
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_background.png' = 432
}

foreach ($entry in $adaptiveAndroidTargets.GetEnumerator()) {
    $fullPath = Join-Path $projectRoot $entry.Key
    Save-PngIcon -sourcePath $backgroundMasterPath -destination $fullPath -size $entry.Value
}

$adaptiveAndroidForegroundTargets = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher_foreground.png' = 108
    'android\app\src\main\res\mipmap-hdpi\ic_launcher_foreground.png' = 162
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher_foreground.png' = 216
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher_foreground.png' = 324
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_foreground.png' = 432
}

foreach ($entry in $adaptiveAndroidForegroundTargets.GetEnumerator()) {
    $fullPath = Join-Path $projectRoot $entry.Key
    Save-PngIcon -sourcePath $foregroundMasterPath -destination $fullPath -size $entry.Value
}

$icoPath = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
Save-WindowsIcon -destination $icoPath
