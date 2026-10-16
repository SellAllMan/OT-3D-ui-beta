param(
    [string]$BackupName = "3d_ui_backup_20261016_234402.lua"
)

$ErrorActionPreference = "Stop"

$repoDir = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta"
$downloadBackupDir = "C:\Users\ASUS\Downloads\3d_ui_backups"
$backupFile = Join-Path $downloadBackupDir $BackupName

if (!(Test-Path $backupFile)) {
    # Check repo backups as fallback
    $backupFile = Join-Path "$repoDir\backups" $BackupName
}

if (!(Test-Path $backupFile)) {
    Write-Error "Backup file $BackupName not found!"
}

Write-Host "Reverting to backup: $backupFile"

# 1. Targets
$destFiles = @(
    "C:\Users\ASUS\Downloads\3d ui beta.lua",
    "C:\Users\ASUS\Downloads\main.lua",
    "$repoDir\3d ui beta.lua",
    "$repoDir\main.lua"
)

foreach ($dest in $destFiles) {
    Copy-Item -Path $backupFile -Destination $dest -Force
    Write-Host "Restored -> $dest"
}

# 2. Git commit & push
Set-Location $repoDir
git add .
git commit -m "revert: rollback to backup $BackupName"
git push origin main

Write-Host "[OK] Rollback complete and pushed to GitHub main successfully!" -ForegroundColor Green
