$filePath = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta\refactored_test.lua"
$lines = Get-Content $filePath

$scopeStack = New-Object System.Collections.Generic.Stack[System.Int32]
$scopeStack.Push(0)

$activeAtHide = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line.StartsWith("--")) { continue }

    if ($line -match 'hideUIWithAnimation\s*=\s*function' -or $line -match 'function\s+hideUIWithAnimation') {
        $totalActive = 0
        foreach ($cnt in $scopeStack) { $totalActive += $cnt }
        $activeAtHide = $totalActive
        Write-Host "Found hideUIWithAnimation at line $($i + 1), active locals = $activeAtHide"
        break
    }

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
