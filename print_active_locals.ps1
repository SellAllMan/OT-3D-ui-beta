$filePath = "c:\Users\ASUS\Downloads\3d ui beta.lua"
$lines = Get-Content $filePath

$scopeStack = New-Object System.Collections.Generic.Stack[System.Collections.ArrayList]
$scopeStack.Push((New-Object System.Collections.ArrayList))

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line.StartsWith("--")) { continue }

    if ($line -match 'hideUIWithAnimation\s*=\s*function' -or $line -match 'function\s+hideUIWithAnimation') {
        Write-Host "--- ALL ACTIVE LOCALS AT LINE $($i + 1) ---"
        $idx = 1
        foreach ($scope in $scopeStack) {
            foreach ($v in $scope) {
                Write-Host "$($idx) -> $v"
                $idx++
            }
        }
        break
    }

    if ($line -match '\b(function|then|do|repeat)\b' -and -not ($line -match '\bend\b')) {
        $scopeStack.Push((New-Object System.Collections.ArrayList))
    }
    elseif ($line -match '\b(end|until)\b') {
        if ($scopeStack.Count -gt 1) {
            $null = $scopeStack.Pop()
        }
    }

    if ($line -match '^local\s+([a-zA-Z0-9_,\s]+)') {
        $vars = $matches[1].Split(',')
        $currentScope = $scopeStack.Peek()
        foreach ($v in $vars) {
            $currentScope.Add("$($i+1): $($v.Trim())")
        }
    }
}
