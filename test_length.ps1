# Let's write a python or powershell script to verify that wrapping in do...end works cleanly
$filePath = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$content = Get-Content $filePath -Raw

Write-Host "File length: $($content.Length)"
