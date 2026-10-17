$filePath = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$lines = Get-Content $filePath

$locals = @()
$depth = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    
    # Count open/close blocks
    # Note: simple check
    if ($line -match '^local\s+([a-zA-Z0-9_]+)') {
        $varName = $matches[1]
        $locals += [PSCustomObject]@{
            Line = $i + 1
            Name = $varName
            Content = $line
        }
    }
}

Write-Host "Total 'local' occurrences found: $($locals.Count)"
Write-Host "Locals around line 1893:"
$locals | Where-Object { $_.Line -ge 1850 -and $_.Line -le 1950 } | ForEach-Object {
    Write-Host "$($_.Line): $($_.Content)"
}
