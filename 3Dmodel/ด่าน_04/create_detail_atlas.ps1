# Original technical artwork, generated locally. No downloaded textures.
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(16,53,37))
$tracePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(38,83,55)),1.5
$silkPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(155,175,145)),1
$ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(24,29,32))
$paper = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215,221,218))
$silk = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(176,193,160))
$font = New-Object System.Drawing.Font 'Arial',13
$small = New-Object System.Drawing.Font 'Arial',9
$large = New-Object System.Drawing.Font 'Arial',26,([System.Drawing.FontStyle]::Bold)
$rng = New-Object System.Random 4013
for ($i=0; $i -lt 120; $i++) {
    $x = $rng.Next(14,460); $y = $rng.Next(18,580)
    $length = $rng.Next(18,70)
    $g.DrawLines($tracePen,[System.Drawing.Point[]]@(
        [System.Drawing.Point]::new($x,$y),[System.Drawing.Point]::new($x+12,$y),
        [System.Drawing.Point]::new($x+26,$y+14),[System.Drawing.Point]::new($x+26,[math]::Min(624,$y+$length))))
    $g.DrawEllipse($silkPen,$x-2,$y-2,4,4)
}
for ($row=0; $row -lt 9; $row++) {
    for ($col=0; $col -lt 5; $col++) {
        $x=15+$col*96; $y=45+$row*62
        $g.DrawRectangle($silkPen,$x,$y,28,14)
        $g.DrawString(('R'+(101+$row*5+$col)),$small,$silk,[single]$x,[single]($y+16))
    }
}
$g.DrawString('ATX  /  REV 1.4',$font,$silk,22,12)
$g.DrawString('PCI EXPRESS    DIMM A1 / B1',$font,$silk,22,602)
function LabelTile([int]$y,[int]$height,[string]$title,[string]$subtitle,[string]$code) {
    $g.FillRectangle($paper,512,$y,512,$height)
    $g.DrawRectangle($silkPen,524,($y+10),488,($height-20))
    $g.DrawString($title,$large,$ink,536,[single]($y+15))
    $g.DrawString($subtitle,$font,$ink,538,[single]($y+62))
    if ($height -gt 120) {
        $g.DrawString('AC 100-240 V ~ 50/60 Hz',$font,$ink,538,[single]($y+96))
        $g.DrawString('+12 V  34 A     +5 V  18 A     +3.3 V  18 A',$small,$ink,538,[single]($y+124))
        $g.DrawString('DISCONNECT POWER BEFORE SERVICE',$small,$ink,538,[single]($y+150))
        for ($j=0;$j -lt 95;$j++) {
            $width=1+($j%3)
            if ($j%5 -ne 0) { $g.FillRectangle($ink,(540+$j*4),($y+184),$width,32) }
        }
        $g.DrawString($code,$small,$ink,538,[single]($y+220))
    }
}
LabelTile 0 256 '450 W  /  ATX' 'HIGH EFFICIENCY POWER SUPPLY' 'SN 04-PSU-001482'
LabelTile 256 96 'NVMe 512 GB' 'PCIe 3.0 x4  /  M.2 2280' ''
LabelTile 352 96 'HDD  1 TB' 'SATA 6 Gb/s  |  7200 RPM' ''
LabelTile 448 96 'DDR4  8 GB' '2666 MT/s  /  1.2 V  /  UDIMM' ''
LabelTile 544 96 'GbE  10/100/1000' 'PCIe x1  |  MAC 02:04:00:00:00:01' ''
$g.FillRectangle($paper,0,640,512,128)
$g.DrawString('12 V DC   /   BRUSHLESS',$large,$ink,20,664)
$g.DrawString('AIRFLOW  >>>    0.18 A',$font,$ink,20,716)
$g.FillRectangle($paper,512,640,512,128)
$g.DrawString('SATA SSD  256 GB',$large,$ink,532,664)
$g.DrawString('6 Gb/s   /   DC +5 V',$font,$ink,532,716)
$output = Join-Path $PSScriptRoot 'textures/pc_detail_atlas_1024.png'
$bitmap.Save($output,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bitmap.Dispose()
foreach ($item in @($tracePen,$silkPen,$ink,$paper,$silk,$font,$small,$large)) { $item.Dispose() }
Write-Output $output
