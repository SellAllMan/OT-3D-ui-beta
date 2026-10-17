$filePath = "C:\Users\ASUS\Downloads\3d ui beta.lua"
$lines = Get-Content $filePath

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match '^local\s+([a-zA-Z0-9_]+)\s*=\s*(Instance\.new|Color3|Vector|UDim|Enum)') {
        Write-Host "$($i + 1): $($line.Substring(0, [Math]::Min(60, $line.Length)))"
    }
}
