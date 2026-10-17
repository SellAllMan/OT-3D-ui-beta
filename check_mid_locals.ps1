$lines = Get-Content "c:\Users\ASUS\Downloads\3d ui beta.lua"
for ($i = 1200; $i -lt 1890; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match '^local\s+([a-zA-Z0-9_,\s]+)') {
        Write-Host "$($i + 1): $($line)"
    }
}
