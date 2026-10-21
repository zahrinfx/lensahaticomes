# make-thumbs.ps1  (versi auto)
# Letak fail ni SEBELAH index4-v4.html (sebelah folder "images").
#
# Skrip ni akan:
#   1. Imbas semua gambar .jpg dalam folder "images"
#   2. Jana gambar kecil  -> thumbs\  (lebar 800px, untuk galeri)
#   3. Jana gambar sederhana -> large\ (lebar 1800px, untuk paparan besar)
#   4. Tulis thumbs-data.js yang mengandungi senarai semua gambar, kategori dan saiz
#
# Jadi nak tambah gambar: letak dalam images\<Kategori>\<Album>\ -> run skrip ni -> upload. Siap.
# Folder baru dalam "images" (contoh: images\Corporate\1\) akan jadi tab baru secara automatik.
# Gambar asal TIDAK diubah. Boleh run berulang kali (gambar yang dah siap dilangkau).
#
# Cara run: buka PowerShell dalam folder ni, kemudian:
#   powershell -ExecutionPolicy Bypass -File .\make-thumbs.ps1

param(
  [int]$ThumbWidth  = 800,
  [int]$LargeWidth  = 1800,
  [int]$Quality     = 82,
  [int]$FeaturedMax = 12
)

# ---------- TETAPAN (boleh ubah) ----------
# Susunan tab. Kategori yang tiada dalam senarai ni akan diletak selepas, ikut abjad.
$Order = @('Potret Individu', 'Engagement', 'Wedding', 'Bayi dan Maternity', 'Convo')

# Nama yang dipaparkan pada tab (kiri = nama folder, kanan = nama paparan).
# Kategori yang tiada di sini akan guna nama folder terus.
$Labels = @{
  'Potret Individu'    = 'Potret'
  'Engagement'         = 'Pertunangan'
  'Wedding'            = 'Perkahwinan'
  'Bayi dan Maternity' = 'Bayi & Maternity'
  'Convo'              = 'Convo'
}
# -------------------------------------------

Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$src = Join-Path $root 'images'
if (-not (Test-Path $src)) {
  Write-Host "Folder 'images' tak jumpa di $root" -ForegroundColor Red
  Read-Host "Tekan Enter untuk tutup"
  exit 1
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

# Betulkan orientasi gambar daripada kamera/telefon (EXIF)
function Fix-Orientation($img) {
  if ($img.PropertyIdList -contains 0x0112) {
    $o = $img.GetPropertyItem(0x0112).Value[0]
    switch ($o) {
      2 { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
      3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
      4 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipX) }
      5 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
      6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
      7 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
      8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }
  }
}

function Save-Resized($img, [int]$width, [string]$dest) {
  if ($img.Width -le $width) {
    $w = $img.Width; $h = $img.Height
  } else {
    $w = $width; $h = [int][math]::Round($img.Height * $width / $img.Width)
  }
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.DrawImage($img, 0, 0, $w, $h)
  $g.Dispose()
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  $bmp.Save($dest, $jpegCodec, $encParams)
  $bmp.Dispose()
  return ,@($w, $h)
}

function Js-Str([string]$s) {
  return '"' + (($s.Replace('\', '\\')).Replace('"', '\"')) + '"'
}

# ---------- Imbas gambar ----------
$files = @(Get-ChildItem -Path $src -Recurse -File | Where-Object { $_.Extension -match '^\.(jpe?g)$' })
$items = @()
foreach ($f in $files) {
  $rel    = $f.FullName.Substring($src.Length).TrimStart('\', '/')
  $relUrl = $rel -replace '\\', '/'
  $parts  = $relUrl -split '/'
  if ($parts.Count -lt 2) { continue }          # abaikan gambar yang terus dalam "images" (tiada kategori)
  $album = ''
  if ($parts.Count -ge 3) { $album = $parts[1] }
  $albumNum = 0
  [void][int]::TryParse($album, [ref]$albumNum)
  $items += [pscustomobject]@{
    File = $f; Rel = $rel; RelUrl = $relUrl; Cat = $parts[0]
    Album = $album; AlbumNum = $albumNum; Name = $f.Name
  }
}

$total = $items.Count
if ($total -eq 0) {
  Write-Host "Tiada gambar .jpg dijumpai dalam $src (dalam folder kategori)" -ForegroundColor Yellow
  Read-Host "Tekan Enter untuk tutup"
  exit 1
}

$cats = @($items | ForEach-Object { $_.Cat } | Select-Object -Unique)
$orderedCats = @($Order | Where-Object { $cats -contains $_ }) + @($cats | Where-Object { $Order -notcontains $_ } | Sort-Object)

# ---------- Jana thumbs + large ----------
$dims = [ordered]@{}
$n = 0; $made = 0; $skipped = 0; $failed = 0

foreach ($it in $items) {
  $n++
  $f     = $it.File
  $thumb = Join-Path (Join-Path $root 'thumbs') $it.Rel
  $large = Join-Path (Join-Path $root 'large')  $it.Rel

  Write-Progress -Activity "Menjana thumbnail" -Status "$n / $total  $($it.RelUrl)" -PercentComplete (100 * $n / $total)

  try {
    $upToDate = (Test-Path $thumb) -and (Test-Path $large) -and
                ((Get-Item $thumb).LastWriteTime -ge $f.LastWriteTime) -and
                ((Get-Item $large).LastWriteTime -ge $f.LastWriteTime)

    if ($upToDate) {
      $t = [System.Drawing.Image]::FromFile($thumb)
      try { $dims["thumbs/$($it.RelUrl)"] = @($t.Width, $t.Height) } finally { $t.Dispose() }
      $skipped++
    } else {
      $img = [System.Drawing.Image]::FromFile($f.FullName)
      try {
        Fix-Orientation $img
        $td = Save-Resized $img $ThumbWidth $thumb
        $null = Save-Resized $img $LargeWidth $large
        $dims["thumbs/$($it.RelUrl)"] = @($td[0], $td[1])
      } finally { $img.Dispose() }
      $made++
    }
  } catch {
    $failed++
    Write-Host "Gagal: $($it.RelUrl)  ($($_.Exception.Message))" -ForegroundColor Red
  }
}
Write-Progress -Activity "Menjana thumbnail" -Completed

# ---------- Senarai gambar ikut kategori ----------
$data = [ordered]@{}
foreach ($c in $orderedCats) {
  $data[$c] = @($items | Where-Object { $_.Cat -eq $c } | Sort-Object AlbumNum, Album, Name | ForEach-Object { 'images/' + $_.RelUrl })
}

# ---------- Pilihan untuk tab "Semua" ----------
# Kalau ada fail featured.txt (satu path setiap baris, contoh: Wedding/1/1-01.jpg), guna senarai tu.
# Kalau tiada, skrip pilih gambar pertama setiap album, selang-seli antara kategori.
$allPaths = @{}
foreach ($c in $orderedCats) { foreach ($p in $data[$c]) { $allPaths[$p] = 1 } }

$featured = @()
$featFile = Join-Path $root 'featured.txt'
if (Test-Path $featFile) {
  foreach ($line in (Get-Content $featFile)) {
    $p = ($line.Trim() -replace '\\', '/')
    if ($p -eq '' -or $p.StartsWith('#')) { continue }
    if (-not $p.StartsWith('images/')) { $p = 'images/' + $p }
    if ($allPaths.ContainsKey($p)) { $featured += $p } else { Write-Host "featured.txt: tak jumpa $p" -ForegroundColor Yellow }
  }
}
if ($featured.Count -eq 0) {
  $firsts = @{}
  foreach ($c in $orderedCats) {
    $seen = @{}; $list = @()
    foreach ($it in ($items | Where-Object { $_.Cat -eq $c } | Sort-Object AlbumNum, Album, Name)) {
      if (-not $seen.ContainsKey($it.Album)) { $seen[$it.Album] = 1; $list += ('images/' + $it.RelUrl) }
    }
    $firsts[$c] = $list
  }
  $round = 0
  while ($featured.Count -lt $FeaturedMax) {
    $added = $false
    foreach ($c in $orderedCats) {
      if ($featured.Count -ge $FeaturedMax) { break }
      if ($round -lt $firsts[$c].Count) { $featured += $firsts[$c][$round]; $added = $true }
    }
    if (-not $added) { break }
    $round++
  }
}

# ---------- Tulis thumbs-data.js ----------
$nl = [Environment]::NewLine
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('// Dijana oleh make-thumbs.ps1 - jangan edit manual, run skrip semula untuk kemas kini.')
[void]$sb.AppendLine('window.PORTFOLIO_DATA = {')
$catLines = foreach ($c in $orderedCats) {
  '  ' + (Js-Str $c) + ': [' + $nl + '    ' + (($data[$c] | ForEach-Object { Js-Str $_ }) -join (',' + $nl + '    ')) + $nl + '  ]'
}
[void]$sb.AppendLine($catLines -join (',' + $nl))
[void]$sb.AppendLine('};')
[void]$sb.AppendLine('window.PORTFOLIO_LABELS = {')
$labLines = foreach ($c in $orderedCats) {
  $lab = $c
  if ($Labels.ContainsKey($c)) { $lab = $Labels[$c] }
  '  ' + (Js-Str $c) + ': ' + (Js-Str $lab)
}
[void]$sb.AppendLine($labLines -join (',' + $nl))
[void]$sb.AppendLine('};')
[void]$sb.AppendLine('window.PORTFOLIO_FEATURED = [')
[void]$sb.AppendLine((($featured | ForEach-Object { '  ' + (Js-Str $_) }) -join (',' + $nl)))
[void]$sb.AppendLine('];')
[void]$sb.AppendLine('window.THUMB_DIMS = {')
$dimLines = foreach ($k in $dims.Keys) { '  {0}: [{1},{2}]' -f (Js-Str $k), $dims[$k][0], $dims[$k][1] }
[void]$sb.AppendLine($dimLines -join (',' + $nl))
[void]$sb.AppendLine('};')
[System.IO.File]::WriteAllText((Join-Path $root 'thumbs-data.js'), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Siap!  Baru dijana: $made | Dilangkau (dah terkini): $skipped | Gagal: $failed" -ForegroundColor Green
Write-Host "Kategori dijumpai:"
foreach ($c in $orderedCats) { Write-Host ("  - {0}  ({1} gambar)" -f $c, $data[$c].Count) }
Write-Host "Tab 'Semua' guna $($featured.Count) gambar pilihan."
Write-Host "Fail dijana di: $root  (thumbs, large, thumbs-data.js)"
Read-Host "Tekan Enter untuk tutup"
