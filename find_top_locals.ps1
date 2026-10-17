$filePath = "C:\Users\ASUS\Downloads\3d ui beta.lua"
$lines = Get-Content $filePath

$topLevelLocals = @()
$depth = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()

    # Skip comments
    if ($trimmed.StartsWith("--")) { continue }

    # Very basic block tracking
    if ($depth -eq 0 -and $trimmed -match '^local\s+([a-zA-Z0-9_,\s]+)') {
        $topLevelLocals += [PSCustomObject]@{
            Line = $i + 1
            Text = $trimmed
        }
    }

    # count ends and block starts
    $openMatches = [regex]::Matches($trimmed, '\b(function|then|do|repeat)\b')
    $closeMatches = [regex]::Matches($trimmed, '\b(end|until)\b')

    $depth += ($openMatches.Count - $closeMatches.Count)
    if ($depth -lt 0) { $depth = 0 }
}

Write-Host "Top level locals count: $($topLevelLocals.Count)"
$topLevelLocals | Select-Object -First 30 | ForEach-Object { Write-Host "$($_.Line): $($_.Text)" }
