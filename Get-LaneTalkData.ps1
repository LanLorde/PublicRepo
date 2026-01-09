<#
.SYNOPSIS
    Exports LaneTalk completed-game data for a bowling center into a flat CSV suitable for Excel/VBA ingestion.

.DESCRIPTION
    - Pulls /completed/<page> from LaneTalk for a configurable number of pages (newest-first).
    - Filters to a lane range (default 23-38).
    - Produces one game score per column (Game1, Game2, ...).
    - Uses the first gameId in each completed row to resolve the lane via the game-detail endpoint.

.NOTES
    - Designed for automation (no menu / no prompts).
    - PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    # Bowling center UUID
    [Parameter()][string]$CenterId = "eb0f0b49-b676-430a-9a69-86bf9638b6b1",

    # LaneTalk API key
    [Parameter()][string]$ApiKey   = "",

    # How many /completed pages to pull (page 1 is newest)
    [Parameter()][ValidateRange(1,500)][int]$Pages = 10,

    # Only keep lanes in this inclusive range
    [Parameter()][ValidateRange(1,200)][int]$MinLane = 23,
    [Parameter()][ValidateRange(1,200)][int]$MaxLane = 38,

    # How many game columns to emit (Game1..GameN). Extra scores beyond this are dropped.
    [Parameter()][ValidateRange(1,20)][int]$MaxGameColumns = 6,

    # Output CSV path
    [Parameter()][string]$OutPath = (Join-Path $PWD "lanetalk_export.csv"),

    # Throttle to avoid hammering the API (per game-detail call)
    [Parameter()][ValidateRange(0,2000)][int]$SleepMs = 25,

    # Safety valve: maximum game-detail calls total
    [Parameter()][ValidateRange(1,200000)][int]$MaxGameDetailCalls = 20000
)

Set-StrictMode -Version 2

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "ApiKey is required. Pass -ApiKey '<key>'"
}

function Invoke-LaneTalkApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet('GET','POST')][string]$Method = 'GET',
        [object]$Body = $null,
        [hashtable]$Headers = $null
    )

    if (-not $Headers) {
        # The web app uses apiKey. (Headers are case-insensitive over HTTP anyway.)
        $Headers = @{
            apiKey  = $ApiKey
            accept  = 'application/json'
            origin  = 'https://livescores.lanetalk.com'
            referer = 'https://livescores.lanetalk.com/'
        }
    }

    if ($Method -eq 'POST') {
        $json = $Body | ConvertTo-Json -Depth 30
        return Invoke-RestMethod -Method POST -Uri $Uri -Headers $Headers -Body $json -ContentType 'application/json' -TimeoutSec 30
    }

    return Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -TimeoutSec 30
}

function Get-LaneTalkCompleted {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Page)

    $uri = "https://api.lanetalk.com/v1/bowlingcenters/$CenterId/completed/$Page"
    Invoke-LaneTalkApi -Uri $uri -Method GET
}

function Get-LaneTalkGameDetail {
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$GameId)

    $headers = @{
        apiKey  = $ApiKey
        accept  = 'application/json'
        origin  = 'https://livescores.lanetalk.com'
        referer = 'https://livescores.lanetalk.com/'
    }

    $candidates = @(
        "https://api.lanetalk.com/v1/games/$GameId",
        "https://api.lanetalk.com/v1/game/$GameId",
        "https://api.lanetalk.com/v1/scorecards/games/$GameId",
        "https://api.lanetalk.com/v1/scorecards/game/$GameId",
        "https://api.lanetalk.com/v1/scorecards/$GameId",
        "https://api.lanetalk.com/v1/scorecard/$GameId"
    )

    foreach ($u in $candidates) {
        try {
            return Invoke-RestMethod -Method GET -Uri $u -Headers $headers -ErrorAction Stop
        } catch {
            # keep trying
        }
    }

    throw "No candidate game-detail endpoints returned 200 for GameId=$GameId"
}

function New-GameColumns {
    param([int]$Count)
    $cols = @()
    for ($i = 1; $i -le $Count; $i++) { $cols += ("Game{0}" -f $i) }
    return $cols
}

$gameCols = New-GameColumns -Count $MaxGameColumns

# Cache to avoid re-fetching same gameId repeatedly
$laneByGameId = @{}
$gameDetailCalls = 0

$results = New-Object System.Collections.Generic.List[object]

for ($page = 1; $page -le $Pages; $page++) {
    $completed = $null
    try {
        $completed = Get-LaneTalkCompleted -Page $page
    } catch {
        Write-Warning ("Failed to pull completed page {0}: {1}" -f $page, $_.Exception.Message)
        continue
    }

    if (-not $completed -or ($completed | Measure-Object).Count -eq 0) {
        break
    }

    foreach ($c in $completed) {
        # Resolve lane from first gameId (completed row is a series)
        $ids = @()
        if ($c.gameIds) { $ids = @($c.gameIds) }
        if ($ids.Count -lt 1) { continue }

        $firstId = [long]$ids[0]
        $lane = $null

        if ($laneByGameId.ContainsKey($firstId)) {
            $lane = $laneByGameId[$firstId]
        } else {
            $gameDetailCalls++
            if ($gameDetailCalls -gt $MaxGameDetailCalls) {
                throw "MaxGameDetailCalls limit hit ($MaxGameDetailCalls)."
            }

            try {
                $g = Get-LaneTalkGameDetail -GameId $firstId
                $lane = $g.lane
            } catch {
                $lane = $null
            }

            $laneByGameId[$firstId] = $lane

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        $laneInt = $null
        if ($null -ne $lane) {
            try { $laneInt = [int]$lane } catch { $laneInt = $null }
        }

        if ($null -eq $laneInt) { continue }
        if ($laneInt -lt $MinLane -or $laneInt -gt $MaxLane) { continue }

        # gameScores => one per column
        $scores = @()
        if ($c.gameScores) { $scores = @($c.gameScores) }

        $row = [ordered]@{
            playerName = $c.playerName
            lane       = $laneInt
            page       = $page
        }

        for ($i = 0; $i -lt $MaxGameColumns; $i++) {
            $col = $gameCols[$i]
            $row[$col] = if ($i -lt $scores.Count) { $scores[$i] } else { "" }
        }

        $results.Add([pscustomobject]$row) | Out-Null
    }
}

# Sort for easier Excel processing: lane, then player
$sorted = $results | Sort-Object lane, playerName

$sorted | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutPath
Write-Host ("Wrote {0} row(s) to {1}" -f ($sorted | Measure-Object).Count, $OutPath) -ForegroundColor Green
