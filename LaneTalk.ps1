# =========================
# LaneTalk
# =========================

# Hardcoded Center ID (as requested)
$script:LaneTalkCenterId = "eb0f0b49-b676-430a-9a69-86bf9638b6b1"

# Put the key that makes your OG curl work RIGHT HERE.
# If LaneTalk rotates it later, update this string.
$script:LaneTalkApiKey = "8tLtPc8UwWvdvbpzRIr0ifCWy250TXUXrGUn"

function Convert-FromUnixTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long]$UnixSeconds,

        [switch]$Utc
    )

    if ($UnixSeconds -le 0) { return $null }

    if ($Utc) {
        return [DateTimeOffset]::FromUnixTimeSeconds($UnixSeconds).UtcDateTime
    }

    return [DateTimeOffset]::FromUnixTimeSeconds($UnixSeconds).ToLocalTime().DateTime
}

function Invoke-LaneTalkApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet("GET","POST")][string]$Method = "GET",
        [object]$Body = $null
    )

    $headers = @{
        apikey  = $script:LaneTalkApiKey
        accept  = "application/json"
        origin  = "https://livescores.lanetalk.com"
        referer = "https://livescores.lanetalk.com/"
    }

    if ($Method -eq "POST") {
        $json = $Body | ConvertTo-Json -Depth 30
        return Invoke-RestMethod -Method POST -Uri $Uri -Headers $headers -Body $json -ContentType "application/json" -TimeoutSec 30
    }

    return Invoke-RestMethod -Method GET -Uri $Uri -Headers $headers -TimeoutSec 30
}

function Get-LaneTalkCompleted {
    [CmdletBinding()]
    param([int]$Page = 1)

    $centerId = $script:LaneTalkCenterId
    $uri = "https://api.lanetalk.com/v1/bowlingcenters/$centerId/completed/$Page"
    Invoke-LaneTalkApi -Uri $uri -Method GET
}

function Get-LaneTalkGameDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long]$GameId
    )

    $headers = @{
        apikey  = $script:LaneTalkApiKey
        accept  = "application/json"
        origin  = "https://livescores.lanetalk.com"
        referer = "https://livescores.lanetalk.com/"
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

function Show-LaneTalkHydratedScoreboardOnce {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$SleepMs = 25,
        [int]$MaxGames = 5000
    )

    $completed = Get-LaneTalkCompleted -Page $Page
    if (-not $completed) {
        Write-Warning "No results returned from /completed/$Page"
        return
    }

    $gameCounter = 0

    $rows = foreach ($c in $completed) {
        $ids = @()
        if ($c.gameIds) { $ids = @($c.gameIds) }

        $laneGames = New-Object System.Collections.Generic.List[string]

        foreach ($gid in $ids) {
            $gameCounter++
            if ($gameCounter -gt $MaxGames) {
                throw "MaxGames limit hit ($MaxGames). Bailing to avoid hammering the API."
            }

            try {
                $g = Get-LaneTalkGameDetail -GameId ([long]$gid)

                $finalScore = $null
                if ($g.scores) { $finalScore = ($g.scores | Select-Object -Last 1) }
                if ($null -eq $finalScore) { $finalScore = $g.score }

                $startLocal = $null
                $endLocal   = $null
                if ($g.startTime) { $startLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime) }
                if ($g.endTime)   { $endLocal   = Convert-FromUnixTime -UnixSeconds ([long]$g.endTime) }

                # Example: "G1 L23 77 (01/06 19:12 -> 19:31)"
                if ($startLocal -and $endLocal) {
                    $laneGames.Add(("G{0} L{1} {2} ({3:MM/dd HH:mm} -> {4:HH:mm})" -f $g.game, $g.lane, $finalScore, $startLocal, $endLocal)) | Out-Null
                } else {
                    $laneGames.Add(("G{0} L{1} {2}" -f $g.game, $g.lane, $finalScore)) | Out-Null
                }
            } catch {
                $laneGames.Add(("G? L? (gameId {0} failed)" -f $gid)) | Out-Null
            }

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        [pscustomobject]@{
            playerName = $c.playerName
            teamName   = $c.teamName
            totalScore = $c.totalScore
            laneGames  = $laneGames -join " | "
        }
    }

    $rows |
        Sort-Object totalScore -Descending |
        Format-Table -AutoSize
}

function Show-LaneTalkPlayerGameDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlayerName,

        # How many /completed pages to scan (start with 1; bump if needed)
        [int]$MaxPages = 3,

        # Small delay to avoid hammering
        [int]$SleepMs = 25
    )

    $PlayerName = $PlayerName.Trim()
    if ([string]::IsNullOrWhiteSpace($PlayerName)) {
        Write-Warning "PlayerName was empty."
        return
    }

    $matches = New-Object System.Collections.Generic.List[object]

    for ($page = 1; $page -le $MaxPages; $page++) {
        $completed = Get-LaneTalkCompleted -Page $page
        if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { break }

        foreach ($c in $completed) {
            if ($null -eq $c.playerName) { continue }

            # case-insensitive "contains" match (works even if they type partial name)
            if ($c.playerName -like "*$PlayerName*") {
                $matches.Add($c) | Out-Null
            }
        }
    }

    if ($matches.Count -eq 0) {
        Write-Warning "No matches for '$PlayerName' in the first $MaxPages page(s) of completed results."
        return
    }

    Write-Host ""
    Write-Host ("Found {0} completed row(s) matching '{1}'" -f $matches.Count, $PlayerName) -ForegroundColor Cyan

    # Pull every game detail. Store in a variable so you can inspect later.
    $script:LaneTalk_LastPlayerGameDetails = New-Object System.Collections.Generic.List[object]

    foreach ($m in $matches) {
        $ids = @()
        if ($m.gameIds) { $ids = @($m.gameIds) }

        foreach ($gid in $ids) {
            $g = Get-LaneTalkGameDetail -GameId ([long]$gid)

            $startLocal = $null
            $endLocal   = $null
            $startUtc   = $null
            $endUtc     = $null
            if ($g.startTime) {
                $startLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime)
                $startUtc   = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime) -Utc
            }
            if ($g.endTime) {
                $endLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.endTime)
                $endUtc   = Convert-FromUnixTime -UnixSeconds ([long]$g.endTime) -Utc
            }

            # Save enriched object for later inspection
            $script:LaneTalk_LastPlayerGameDetails.Add([pscustomobject]@{
                raw          = $g
                startLocal   = $startLocal
                endLocal     = $endLocal
                startUtc     = $startUtc
                endUtc       = $endUtc
            }) | Out-Null

            Write-Host ""
            Write-Host ("=== {0} | Team: {1} | GameId: {2} | G{3} Lane {4} ===" -f $g.playerName, $g.teamName, $g.id, $g.game, $g.lane) -ForegroundColor Yellow

            if ($startLocal -and $endLocal) {
                Write-Host ("Start: {0}  End: {1}  (Local: {2:MM/dd/yyyy HH:mm:ss} -> {3:HH:mm:ss})" -f $g.startTime, $g.endTime, $startLocal, $endLocal)
                Write-Host ("UTC:   {0:MM/dd/yyyy HH:mm:ss} -> {1:HH:mm:ss}" -f $startUtc, $endUtc)
            } else {
                Write-Host ("Start: {0}  End: {1}" -f $g.startTime, $g.endTime)
            }

            Write-Host ("ScoreType: {0}  CompetitionId: {1}" -f $g.scoreType, $g.competitionId)

            if ($g.scores) {
                Write-Host "`nScores (by frame/progression):" -ForegroundColor DarkCyan
                for ($i = 0; $i -lt $g.scores.Count; $i++) {
                    "{0,2}: {1}" -f $i, $g.scores[$i]
                }
            }

            if ($g.throws) {
                Write-Host "`nThrows:" -ForegroundColor DarkCyan
                for ($i = 0; $i -lt $g.throws.Count; $i++) {
                    "{0,2}: {1}" -f $i, $g.throws[$i]
                }
            }

            if ($g.pins) {
                Write-Host "`nPins:" -ForegroundColor DarkCyan
                for ($i = 0; $i -lt $g.pins.Count; $i++) {
                    "{0,2}: {1}" -f $i, $g.pins[$i]
                }
            }

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }
    }

    Write-Host ""
    Write-Host "Saved full game-detail objects to:`n  `$script:LaneTalk_LastPlayerGameDetails" -ForegroundColor Green
    Write-Host "Example: `$script:LaneTalk_LastPlayerGameDetails[0].raw | Format-List *" -ForegroundColor Green
}

function Export-LaneTalkPage1PlayerLaneGameScoresToCsv {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PWD "lanetalk_page1_player_lane_gamescores.csv"),
        [int]$SleepMs = 25,
        [int]$MaxGames = 5000
    )

    $completed = Get-LaneTalkCompleted -Page 1
    if (-not $completed) {
        Write-Warning "No results returned from /completed/1"
        return
    }

    $gameCounter = 0

    $rows = foreach ($c in $completed) {
        $ids = @()
        if ($c.gameIds) { $ids = @($c.gameIds) }

        # Collect lane(s) for that player's games
        $lanes = New-Object System.Collections.Generic.List[string]

        foreach ($gid in $ids) {
            $gameCounter++
            if ($gameCounter -gt $MaxGames) {
                throw "MaxGames limit hit ($MaxGames). Bailing to avoid hammering the API."
            }

            try {
                $g = Get-LaneTalkGameDetail -GameId ([long]$gid)
                if ($null -ne $g.lane -and "$($g.lane)".Length -gt 0) {
                    $lanes.Add([string]$g.lane) | Out-Null
                }
            } catch {
                # ignore lane fetch failures for export
            }

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        # De-dupe lanes (some games may be same lane)
        $laneText = ($lanes | Select-Object -Unique) -join ","

        [pscustomobject]@{
            playerName = $c.playerName
            lane       = $laneText
            gameScores = if ($c.gameScores) { @($c.gameScores) -join "," } else { "" }
        }
    }

    $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported to: $Path" -ForegroundColor Green
}

function Start-LaneTalkMenu {
    while ($true) {
        Write-Host ""
        Write-Host "LaneTalk" -ForegroundColor Cyan
        Write-Host "CenterId: $($script:LaneTalkCenterId)" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host " 1) One-shot scoreboard (Page 1)"
        Write-Host " 2) Show full game details for a player name"
        Write-Host " 3) Export Page 1 (playerName,lane,gameScores) to CSV"
        Write-Host " 0) Exit"
        Write-Host ""

        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" { Show-LaneTalkHydratedScoreboardOnce -Page 1 -SleepMs 25 -MaxGames 5000 }
            "2" {
                $name = Read-Host "Enter player name (partial ok)"
                $maxPages = 3
                Show-LaneTalkPlayerGameDetails -PlayerName $name -MaxPages $maxPages -SleepMs 25
            }
            "3" {
                $default = Join-Path $PWD "lanetalk_page1_player_lane_gamescores.csv"
                $path = Read-Host "CSV output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }

                Export-LaneTalkPage1PlayerLaneGameScoresToCsv -Path $path -SleepMs 25 -MaxGames 5000
            }
            "0" { return }
            default { Write-Warning "Unknown option: $choice" }
        }
    }
}

# Auto-launch menu
Start-LaneTalkMenu
