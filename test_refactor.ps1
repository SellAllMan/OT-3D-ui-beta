$src = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$text = Get-Content $src -Raw

# 1. Screen HUD block
# Before:
# local screenHudGui = Instance.new("ScreenGui")
# After:
# local screenHudGui, hudContainer, hudStroke, speedNumLabel, unitLabel, gaugeFill, autoJumpBtn, autoJumpStroke, btnStatusText, camlockBtn, camlockStroke, camlockStatusText, setCamlockButtonVisible, updateCamlockButtonVisual
# do
#   screenHudGui = Instance.new("ScreenGui")
#   ...

Write-Host "Read length: $($text.Length)"
