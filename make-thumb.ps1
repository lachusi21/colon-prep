# Compose a 1200x630 share thumbnail: teal panel, clinic name in an outlined
# pill, the page title, and the two cut-out doctors standing on the bottom edge.
Add-Type -AssemblyName System.Drawing

$dir  = 'C:\MyProjects7'
$outP = Join-Path $dir 'thumb.png'
$W = 1200; $H = 630; $PAD = 70

$teal   = [System.Drawing.ColorTranslator]::FromHtml('#0A8087')
$yellow = [System.Drawing.ColorTranslator]::FromHtml('#FFD97A')

$bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode        = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode    = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode      = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint    = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear($teal)

$white     = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$softWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(238, 255, 255, 255))
$dimWhite  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
$yellowBr  = New-Object System.Drawing.SolidBrush $yellow
$penWhite  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(165, 255, 255, 255)), 3

$fontPill  = New-Object System.Drawing.Font 'Microsoft JhengHei', 30, ([System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font 'Microsoft JhengHei', 76, ([System.Drawing.FontStyle]::Bold)
$fontSub   = New-Object System.Drawing.Font 'Microsoft JhengHei', 25
$fontFoot  = New-Object System.Drawing.Font 'Microsoft JhengHei', 21

# --- the two doctors, standing on the bottom edge, right aligned -------------
$figH = 330
$gap  = 14
$imgs = @()
foreach ($n in @('mascot-a.png', 'mascot-b.png')) {
    $im = [System.Drawing.Bitmap]::FromFile((Join-Path $dir $n))
    $imgs += ,@($im, [int][Math]::Round($figH * $im.Width / $im.Height))
}
$figTotal = $imgs[0][1] + $imgs[1][1] + $gap
$x = $W - $PAD - $figTotal
foreach ($pair in $imgs) {
    $g.DrawImage($pair[0], $x, ($H - $figH), $pair[1], $figH)
    $x += $pair[1] + $gap
    $pair[0].Dispose()
}

# --- clinic name in an outlined pill ----------------------------------------
$clinic = '周中凱腸胃內科診所'
$cs = $g.MeasureString($clinic, $fontPill)
$pillH = [int]($cs.Height + 26)
$pillW = [int]($cs.Width + 56)
$pillY = 96
$rad = $pillH / 2
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc($PAD, $pillY, $rad * 2, $pillH, 90, 180)
$path.AddArc(($PAD + $pillW - $rad * 2), $pillY, $rad * 2, $pillH, 270, 180)
$path.CloseFigure()
$g.DrawPath($penWhite, $path)
$g.DrawString($clinic, $fontPill, $white, ($PAD + 28), ($pillY + 12))

# --- title, accent rule, subtitle -------------------------------------------
$titleY = $pillY + $pillH + 34
$g.DrawString('清腸衛教指引', $fontTitle, $white, ($PAD - 8), $titleY)
$ts = $g.MeasureString('清腸衛教指引', $fontTitle)

$ruleY = $titleY + $ts.Height + 16
$g.FillRectangle($yellowBr, $PAD, $ruleY, 132, 9)

$subY = $ruleY + 40
$g.DrawString('保可淨　易暢淨低渣代餐', $fontSub, $softWhite, ($PAD - 4), $subY)
$g.DrawString('填入檢查日期，自動排出你的時程', $fontSub, $dimWhite, ($PAD - 4), ($subY + 46))

$g.DrawString('LINE  @420genld', $fontFoot, $dimWhite, ($PAD - 4), ($H - $PAD - 22))

$bmp.Save($outP, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("thumb.png  {0}x{1}" -f $W, $H)

# --- favicon: the first doctor's head on a teal square ----------------------
$ICO = 512
$ib = New-Object System.Drawing.Bitmap($ICO, $ICO, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ig = [System.Drawing.Graphics]::FromImage($ib)
$ig.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$ig.Clear($teal)
$face = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'mascot-a.png'))
# her head sits at roughly x4..141, y22..148 inside the 190x238 cut-out
$scale = 330.0 / 126.0
$ig.DrawImage($face,
    [int]($ICO / 2 - 72 * $scale), [int]($ICO * 0.46 - 85 * $scale),
    [int]($face.Width * $scale), [int]($face.Height * $scale))
$face.Dispose()
$ib.Save((Join-Path $dir 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$ig.Dispose(); $ib.Dispose()
Write-Output ("icon.png   {0}x{0}" -f $ICO)
