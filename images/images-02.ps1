# =====================================================
# Rename Image Extensions to Lowercase
# Author: ChatGPT
# =====================================================

$rootFolder = Get-Location

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " IMAGE EXTENSION LOWERCASE CONVERTER "
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$files = Get-ChildItem -Path $rootFolder -Recurse -File

$count = 0

foreach ($file in $files) {

    $extension = $file.Extension

    if ($extension -cmatch '\.(JPG|JPEG|PNG)$') {

        $newName = $file.Name.Substring(
            0,
            $file.Name.Length - $extension.Length
        ) + $extension.ToLower()

        $newPath = Join-Path $file.DirectoryName $newName

        try {

            Rename-Item `
                -Path $file.FullName `
                -NewName $newName `
                -ErrorAction Stop

            Write-Host "Renamed:" -ForegroundColor Green
            Write-Host "  $($file.Name) -> $newName"

            $count++
        }
        catch {
            Write-Host "Failed:" -ForegroundColor Red
            Write-Host "  $($file.FullName)"
        }
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " DONE"
Write-Host " Total files renamed: $count"
Write-Host "=====================================" -ForegroundColor Cyan