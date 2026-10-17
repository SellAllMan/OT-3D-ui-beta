$filePath = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta\refactored_test.lua"
$lines = Get-Content $filePath

for ($i = 0; $i -lt 1893; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match '^local\s+([a-zA-Z0-9_,\s]+)') {
        Write-Host "$($i + 1): $($line.Substring(0, [Math]::Min(70, $line.Length)))"
    }
}
