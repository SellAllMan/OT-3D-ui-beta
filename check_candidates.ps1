$filePath = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$content = Get-Content $filePath -Raw

$candidates = @(
    "hudAccentLine", "hudTitle", "gaugeBackground", "camlockIcon",
    "backContainer", "backSidebar", "backSidebarStroke", "backMainWindow", "backMainStroke",
    "sidebarStroke", "trackLayout",
    "wardrobeBackContainer", "wardrobeBackMainWindow", "wardrobeBackStroke",
    "wardrobeStroke", "wardrobeTitle", "wardrobeSubTitle", "wardrobePage", "wardrobeLayout",
    "wardrobePadding", "wardrobeVisualBar", "wardrobeBarStroke",
    "profileImage", "statusDot", "statusStroke", "resizeHandle", "visualBar", "barStroke"
)

foreach ($c in $candidates) {
    $matches = [regex]::Matches($content, "\b$c\b")
    Write-Host "$c occurrences: $($matches.Count)"
}
