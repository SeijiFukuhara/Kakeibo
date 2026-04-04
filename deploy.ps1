# deploy.ps1 - Copy Windows Release build to Desktop

$source = "$PSScriptRoot\build\windows\x64\runner\Release"
$dest   = "$env:USERPROFILE\Desktop\MyFlutterApp_Deploy"

Write-Host "Source: $source"
Write-Host "Dest:   $dest"
Write-Host ""

if (Test-Path $dest) {
    Write-Host "Removing existing folder..."
    Remove-Item $dest -Recurse -Force
}
New-Item -ItemType Directory -Path $dest | Out-Null

foreach ($f in (Get-ChildItem -Path $source -Filter "*.exe" -File)) {
    Copy-Item $f.FullName -Destination $dest
    Write-Host "Copied: $($f.Name)"
}

foreach ($f in (Get-ChildItem -Path $source -Filter "*.dll" -File)) {
    Copy-Item $f.FullName -Destination $dest
    Write-Host "Copied: $($f.Name)"
}

$dataDir = Join-Path $source "data"
if (Test-Path $dataDir) {
    Copy-Item $dataDir -Destination $dest -Recurse
    Write-Host "Copied: data\"
}

Write-Host ""
Write-Host "=== Deploy complete ===" -ForegroundColor Green
Write-Host "Location: $dest"
Write-Host ""
Write-Host "--- Files ---"
Get-ChildItem $dest -Recurse | Where-Object { -not $_.PSIsContainer } |
    ForEach-Object {
        $rel  = $_.FullName.Substring($dest.Length + 1)
        $size = "{0,8:N0} KB" -f ($_.Length / 1024)
        Write-Host "  $size   $rel"
    }
