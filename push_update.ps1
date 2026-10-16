param(
    [string]$CommitMessage = "Update 3D UI features"
)

$ErrorActionPreference = "Stop"

$repoDir = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta"
$downloadSource = "C:\Users\ASUS\Downloads\3d ui beta.lua"
$repoMainFile = "$repoDir\3d ui beta.lua"
$repoMainLua = "$repoDir\main.lua"
$repoBackupDir = "$repoDir\backups"
$downloadBackupDir = "C:\Users\ASUS\Downloads\3d_ui_backups"

if (!(Test-Path $repoBackupDir)) { New-Item -ItemType Directory -Path $repoBackupDir -Force | Out-Null }
if (!(Test-Path $downloadBackupDir)) { New-Item -ItemType Directory -Path $downloadBackupDir -Force | Out-Null }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFileName = "3d_ui_backup_$timestamp.lua"

if (Test-Path $downloadSource) {
    Copy-Item $downloadSource "$repoBackupDir\$backupFileName" -Force
    Copy-Item $downloadSource "$downloadBackupDir\$backupFileName" -Force
    Copy-Item $downloadSource $repoMainFile -Force
    Copy-Item $downloadSource $repoMainLua -Force
    Copy-Item $downloadSource "C:\Users\ASUS\Downloads\main.lua" -Force
    Write-Host "[OK] Backup created: $backupFileName" -ForegroundColor Green
}

$maxBackups = 10
Get-ChildItem -Path $repoBackupDir -Filter "*.lua" | Sort-Object CreationTime -Descending | Select-Object -Skip $maxBackups | Remove-Item -Force
Get-ChildItem -Path $downloadBackupDir -Filter "*.lua" | Sort-Object CreationTime -Descending | Select-Object -Skip $maxBackups | Remove-Item -Force

Set-Location $repoDir
git add .
git commit -m $CommitMessage
git push origin main

Write-Host "[OK] Pushed to GitHub main successfully!" -ForegroundColor Cyan
