#requires -Version 5.1
# Pure parsers; no ADB, device access, global state or output of raw diagnostics.
function ConvertFrom-ProjectorMeminfo([string]$Raw) {
    $values = @{}
    foreach ($line in ($Raw -split '\r?\n')) {
        if ($line -cmatch '^(MemTotal|MemAvailable):') {
            if ($line -cnotmatch '^(MemTotal|MemAvailable):\s+([0-9]+)\s+kB\s*$') {
                throw 'Invalid memory counter format'
            }
            $key = [string]$Matches[1]
            if ($values.ContainsKey($key)) { throw 'Duplicate memory field' }
            $number = [long]0
            if (-not [long]::TryParse($Matches[2], [ref]$number)) {
                throw 'Memory counter overflow'
            }
            $values[$key] = $number
        }
    }
    if (-not $values.ContainsKey('MemTotal') -or
        -not $values.ContainsKey('MemAvailable') -or
        $values['MemTotal'] -le 0 -or
        $values['MemAvailable'] -lt 0 -or
        $values['MemAvailable'] -gt $values['MemTotal']) {
        throw 'Missing or inconsistent memory counters'
    }
    return [pscustomobject]@{
        MemTotal = $values['MemTotal']
        MemAvailable = $values['MemAvailable']
    }
}

function ConvertFrom-ProjectorPss([string]$Raw) {
    $matchesFound = @([regex]::Matches($Raw,
        '(?m)^\s*TOTAL\s+([0-9]+)\s+[0-9]+\s+[0-9]+\s*$', 'IgnoreCase'))
    if ($matchesFound.Count -ne 1) { return $null }
    $number = [long]0
    if (-not [long]::TryParse($matchesFound[0].Groups[1].Value, [ref]$number)) {
        return $null
    }
    return $number
}
