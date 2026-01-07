# =========================
# LaneTalk - Minimal Hydrated Scoreboard
# One menu option: One-shot scoreboard with lane + game#
# =========================

# Hardcoded Center ID (as requested)
$script:LaneTalkCenterId = "eb0f0b49-b676-430a-9a69-86bf9638b6b1"

# Put the key that makes your OG curl work RIGHT HERE.
# If LaneTalk rotates it later, update this string.
$script:LaneTalkApiKey = "8tLtPc8UwWvdvbpzRIr0ifCWy250TXUXrGUn"

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

                # Example: "G1 L23 77"
                $finalScore = $null
                if ($g.scores) { $finalScore = ($g.scores | Select-Object -Last 1) }
                if ($null -eq $finalScore) { $finalScore = $g.score }

                $laneGames.Add(("G{0} L{1} {2}" -f $g.game, $g.lane, $finalScore)) | Out-Null
            } catch {
                $laneGames.Add(("G? L? (gameId {0} failed)" -f $gid)) | Out-Null
            }

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        [pscustomobject]@{
            playerName = $c.playerName
            teamName   = $c.teamName
            totalScore = $c.totalScore
            gameScores = if ($c.gameScores) { @($c.gameScores) -join ", " } else { "" }
            laneGames  = $laneGames -join " | "
        }
    }

    $rows |
        Sort-Object totalScore -Descending |
        Format-Table -AutoSize
}

function Start-LaneTalkMenu {
    while ($true) {
        Write-Host ""
        Write-Host "LaneTalk - Minimal" -ForegroundColor Cyan
        Write-Host "CenterId: $($script:LaneTalkCenterId)" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host " 1) One-shot hydrated scoreboard (Page 1)"
        Write-Host " 0) Exit"
        Write-Host ""

        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" { Show-LaneTalkHydratedScoreboardOnce -Page 1 -SleepMs 25 -MaxGames 5000 }
            "0" { return }
            default { Write-Warning "Unknown option: $choice" }
        }
    }
}

# Auto-launch menu
Start-LaneTalkMenu