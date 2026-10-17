$filePath = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$lines = Get-Content $filePath

# Let's count depth-aware active locals at each line
$depth = 0
$scopeStack = New-Object System.Collections.Generic.Stack[System.Int32]
$scopeStack.Push(0) # top level count

$activeLocalsAt1893 = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line.StartsWith("--")) { continue }

    if ($i + 1 -eq 1893) {
        $totalActive = 0
        foreach ($cnt in $scopeStack) { $totalActive += $cnt }
        $activeLocalsAt1893 = $totalActive
        break
    }

    # count block openers
    if ($line -match '\b(function|then|do|repeat)\b' -and -not ($line -match '\bend\b')) {
        $scopeStack.Push(0)
    }
    elseif ($line -match '\b(end|until)\b') {
        if ($scopeStack.Count -gt 1) {
            $null = $scopeStack.Pop()
        }
    }

    if ($line -match '^local\s+([a-zA-Z0-9_,\s]+)') {
        $vars = $matches[1].Split(',')
        $currentScopeCount = $scopeStack.Pop()
        $currentScopeCount += $vars.Count
        $scopeStack.Push($currentScopeCount)
    }
}

Write-Host "Active locals at line 1893 before refactoring: $activeLocalsAt1893"
