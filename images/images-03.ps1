# =====================================================
# Lensa Hati Comes - SEO Image Renamer
# =====================================================

$rootFolder = Get-Location

Write-Host ""
Write-Host "Lensa Hati Comes - SEO Image Renamer" -ForegroundColor Cyan
Write-Host ""

$files = Get-ChildItem -Path $rootFolder -Recurse -File

$count = 0

foreach ($file in $files)
{
    $folderName = Split-Path $file.DirectoryName -Leaf

    $category = $folderName.ToLower()

    $category = $category `
        -replace '&','dan' `
        -replace '[^a-z0-9 ]','' `
        -replace '\s+','-'

    $extension = $file.Extension.ToLower()

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

    if ($baseName -match '\d+')
    {
        $number = $matches[0].PadLeft(2,'0')
    }
    else
    {
        $number = "{0:D2}" -f ($count + 1)
    }

    $newName = "$category-$number$extension"

    try
    {
        Rename-Item `
            -Path $file.FullName `
            -NewName $newName `
            -ErrorAction Stop

        Write-Host "$($file.Name) -> $newName" -ForegroundColor Green

        $count++
    }
    catch
    {
        Write-Host "FAILED : $($file.Name)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Total renamed : $count files" -ForegroundColor Yellow