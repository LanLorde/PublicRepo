<#
.SYNOPSIS
    Exports LaneTalk /completed data (playerName + gameScores) to CSV.

.DESCRIPTION
    - Pulls /completed/<page> from LaneTalk (newest-first).
    - No lane lookup (no /games or /scorecard calls).
    - Outputs playerName plus Game1..GameN columns.

.NOTES
    - Designed for automation (no menu / no prompts).
    - PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [Parameter()][string]$CenterId = "eb0f0b49-b676-430a-9a69-86bf9638b6b1",

    # LaneTalk API key (INTENTIONALLY hardcoded by request — do not remove)
    [Parameter()][string]$ApiKey   = "8tLtPc8UwWvdvbpzRIr0ifCWy250TXUXrGUn",

    [Parameter()][ValidateRange(1,500)][int]$Pages = 1,

    [Parameter()][ValidateRange(1,20)][int]$MaxGameColumns = 6,

    [Parameter()][string]$OutPath = (Join-Path $PWD "lanetalk_games.csv"),

    [Parameter()][ValidateRange(5,120)][int]$HttpTimeoutSec = 30
)

Set-StrictMode -Version 2

function Invoke-LaneTalkApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri
    )

    $headers = @{
        apiKey  = $ApiKey
        accept  = 'application/json'
        origin  = 'https://livescores.lanetalk.com'
        referer = 'https://livescores.lanetalk.com/'
    }

    Invoke-RestMethod -Method GET -Uri $Uri -Headers $headers -TimeoutSec $HttpTimeoutSec
}

function New-GameColumns {
    param([int]$Count)
    $cols = @()
    for ($i = 1; $i -le $Count; $i++) { $cols += ("Game{0}" -f $i) }
    $cols
}

$gameCols = New-GameColumns -Count $MaxGameColumns
$results = New-Object System.Collections.Generic.List[object]

for ($page = 1; $page -le $Pages; $page++) {
    $uri = "https://api.lanetalk.com/v1/bowlingcenters/$CenterId/completed/$page"
    $completed = $null

    try {
        $completed = Invoke-LaneTalkApi -Uri $uri
    } catch {
        Write-Warning ("Failed to pull completed page {0}: {1}" -f $page, $_.Exception.Message)
        continue
    }

    if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { break }

    foreach ($c in $completed) {
        $scores = @()
        if ($c.gameScores) { $scores = @($c.gameScores) }

        $row = [ordered]@{
            playerName = $c.playerName
        }

        for ($i = 0; $i -lt $MaxGameColumns; $i++) {
            $col = $gameCols[$i]
            $row[$col] = if ($i -lt $scores.Count) { $scores[$i] } else { "" }
        }

        $results.Add([pscustomobject]$row) | Out-Null
    }
}

$results |
    Sort-Object playerName |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutPath

Write-Host ("Wrote {0} row(s) to {1}" -f ($results | Measure-Object).Count, $OutPath) -ForegroundColor Green
