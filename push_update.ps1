<#
.SYNOPSIS
    ระบบสำรองไฟล์และพุชขึ้น GitHub อัตโนมัติสำหรับ OT-3D-ui-beta
    - เก็บไฟล์สำรองย้อนหลัง (อย่างน้อย 3-10 อัปเดตล่าสุด)
    - ซิงค์ไฟล์ระหว่าง Downloads และโฟลเดอร์ Repository
    - ทำการ Git Commit และ Push ไปยัง https://github.com/SellAllMan/OT-3D-ui-beta.git
#>

param(
    [string]$CommitMessage = "Update 3D UI features"
)

$ErrorActionPreference = "Stop"

$repoDir = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta"
$downloadSource = "C:\Users\ASUS\Downloads\3d ui beta.lua"
$repoMainFile = "$repoDir\3d ui beta.lua"
$repoBackupDir = "$repoDir\backups"
$downloadBackupDir = "C:\Users\ASUS\Downloads\3d_ui_backups"

# สร้างโฟลเดอร์สำรองถ้ายังไม่มี
if (!(Test-Path $repoBackupDir)) { New-Item -ItemType Directory -Path $repoBackupDir -Force | Out-Null }
if (!(Test-Path $downloadBackupDir)) { New-Item -ItemType Directory -Path $downloadBackupDir -Force | Out-Null }

# ทำการสำรองไฟล์เวอร์ชันก่อนหน้าตามเวลา (Timestamp)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFileName = "3d_ui_backup_$timestamp.lua"

if (Test-Path $downloadSource) {
    Copy-Item $downloadSource "$repoBackupDir\$backupFileName" -Force
    Copy-Item $downloadSource "$downloadBackupDir\$backupFileName" -Force
    Copy-Item $downloadSource $repoMainFile -Force
    Write-Host "[✓] สำรองไฟล์สำเร็จ: $backupFileName" -ForegroundColor Green
}

# จัดการลบไฟล์สำรองที่เก่าเกินไป (เก็บไว้อย่างน้อย 10 อัปเดตล่าสุด)
$maxBackups = 10
Get-ChildItem -Path $repoBackupDir -Filter "*.lua" | Sort-Object CreationTime -Descending | Select-Object -Skip $maxBackups | Remove-Item -Force
Get-ChildItem -Path $downloadBackupDir -Filter "*.lua" | Sort-Object CreationTime -Descending | Select-Object -Skip $maxBackups | Remove-Item -Force

# รันคำสั่ง Git Push
Set-Location $repoDir
git add .
git commit -m $CommitMessage
git push origin main

Write-Host "[✓] พุชขึ้น GitHub (main) เรียบร้อยแล้ว!" -ForegroundColor Cyan
