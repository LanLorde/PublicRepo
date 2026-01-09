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
        # PowerShell hashtable keys are case-insensitive, so we can't include both apikey + apiKey.
        # The web app uses "apiKey".
        apiKey  = $script:LaneTalkApiKey
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

function Get-LaneTalkCenterStatus {
    [CmdletBinding()]
    param(
        # Cache for this many seconds
        [int]$CacheSeconds = 60,
        [switch]$Force,
        # Don't throw when no endpoint works
        [switch]$Quiet
    )

    if (-not $Force -and $script:LaneTalkCenterStatusCache -and $script:LaneTalkCenterStatusCache.When) {
        $age = (New-TimeSpan -Start $script:LaneTalkCenterStatusCache.When -End (Get-Date)).TotalSeconds
        if ($age -lt $CacheSeconds -and $script:LaneTalkCenterStatusCache.Data) {
            return $script:LaneTalkCenterStatusCache.Data
        }
    }

    $centerId = $script:LaneTalkCenterId

    # From the web app bundle: bowling center endpoint is /bowlingcenters/:uuid
    # (We still try a few alternates just in case.)
    $candidates = @(
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId",
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId/web",
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId/settings",
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId/live",
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId/web_center_live_scoring"
    )

    $data = $null
    $current = $null
    $urlUsed = $null
    $lastError = $null

    foreach ($u in $candidates) {
        try {
            $data = Invoke-LaneTalkApi -Uri $u -Method GET
            if (-not $data) { continue }

            # Normalize common shapes we have seen from the web app.
            $candidateCurrent = $null
            if ($data.state -and $data.state.current) {
                $candidateCurrent = $data.state.current
            } elseif ($data.current) {
                $candidateCurrent = $data.current
            } else {
                $candidateCurrent = $data
            }

            # Sanity check: some endpoints report a weird "activeGames" that can exceed lanes.
            # If that happens, keep trying other endpoints.
            if ($null -ne $candidateCurrent -and $null -ne $candidateCurrent.lanes -and $null -ne $candidateCurrent.activeGames) {
                try {
                    if ([int]$candidateCurrent.activeGames -gt [int]$candidateCurrent.lanes) {
                        continue
                    }
                } catch {
                    # if parsing fails, accept it
                }
            }

            $current = $candidateCurrent
            $urlUsed = $u
            break
        } catch {
            $lastError = $_
            continue
        }
    }

    $script:LaneTalkCenterStatusCache = [pscustomobject]@{
        When     = Get-Date
        Data     = $current
        Raw      = $data
        UrlUsed  = $urlUsed
        UrlTried = ($candidates -join "; ")
        Error    = $lastError
    }

    if (-not $current -and -not $Quiet) {
        $msg = "Get-LaneTalkCenterStatus: no candidate endpoint returned data. Tried: $($script:LaneTalkCenterStatusCache.UrlTried)"
        if ($lastError) { $msg += "`nLast error: $($lastError.Exception.Message)" }
        throw $msg
    }

    return $current
}

function Format-LaneTalkScoreboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Game
    )

    $throws = @()
    $scores = @()

    if ($Game.throws) { $throws = @($Game.throws) }
    if ($Game.scores) { $scores = @($Game.scores) }

    # Convert to strings (some payloads are ints)
    $throws = $throws | ForEach-Object { if ($null -eq $_) { "" } else { [string]$_ } }
    $scores = $scores | ForEach-Object { if ($null -eq $_) { "" } else { [string]$_ } }

    function Convert-LaneTalkThrow([string]$t) {
        $t = ($t ?? "").Trim()
        if ($t -eq "") { return "" }
        if ($t -eq "0") { return "-" }   # gutter / miss
        return $t
    }

    # Split throws into 10 frames (1-9: 2 balls, 10th: 3 balls)
    $frames = New-Object System.Collections.Generic.List[object]
    $idx = 0

    for ($f = 1; $f -le 9; $f++) {
        $a = if ($idx -lt $throws.Count) { Convert-LaneTalkThrow $throws[$idx] } else { "" }
        $b = if (($idx + 1) -lt $throws.Count) { Convert-LaneTalkThrow $throws[$idx + 1] } else { "" }
        $frames.Add([pscustomobject]@{ A = $a; B = $b; C = "" }) | Out-Null
        $idx += 2
    }

    $a10 = if ($idx -lt $throws.Count) { Convert-LaneTalkThrow $throws[$idx] } else { "" }
    $b10 = if (($idx + 1) -lt $throws.Count) { Convert-LaneTalkThrow $throws[$idx + 1] } else { "" }
    $c10 = if (($idx + 2) -lt $throws.Count) { Convert-LaneTalkThrow $throws[$idx + 2] } else { "" }
    $frames.Add([pscustomobject]@{ A = $a10; B = $b10; C = $c10 }) | Out-Null

    # Cumulative scores (use last 10 if more exist)
    $cum = @()
    if ($scores.Count -gt 0) {
        $cum = if ($scores.Count -gt 10) { $scores[-10..-1] } else { $scores }
    } else {
        $cum = @("","","","","","","","","","")
    }

    function Pad([string]$s, [int]$w) {
        if ($null -eq $s) { $s = "" }
        if ($s.Length -gt $w) { return $s.Substring(0, $w) }
        return $s.PadRight($w)
    }

    function Center([string]$s, [int]$w) {
        if ($null -eq $s) { $s = "" }
        if ($s.Length -ge $w) { return $s.Substring(0, $w) }
        $pad = $w - $s.Length
        $left = [int][Math]::Floor($pad / 2)
        $right = $pad - $left
        return (" " * $left) + $s + (" " * $right)
    }

    # Frame widths: 1-9 = 7 chars inside (A | B), 10th = 11 chars inside (A | B | C)
    $w9  = 7
    $w10 = 11

    # Box drawing
    $top = "┌" + (("─" * $w9 + "┬") * 9) + ("─" * $w10) + "┐"
    $mid = "├" + (("─" * $w9 + "┼") * 9) + ("─" * $w10) + "┤"
    $bot = "└" + (("─" * $w9 + "┴") * 9) + ("─" * $w10) + "┘"

    # Numbers row (centered)
    $nums = "│"
    for ($i = 1; $i -le 9; $i++) {
        $nums += (Center ([string]$i) $w9) + "│"
    }
    $nums += (Center "10" $w10) + "│"

    # Balls row (with inner pipes between throws)
    $balls = "│"
    for ($i = 0; $i -lt 9; $i++) {
        $a = $frames[$i].A
        $b = $frames[$i].B

        # If strike, show just "X" without inner pipe
        if ($a -eq "X" -and [string]::IsNullOrWhiteSpace($b)) {
            $cell = Center "X" $w9
            $balls += $cell + "│"
        } else {
            $cell = "{0} | {1}" -f $a, $b
            $balls += (Pad $cell $w9) + "│"
        }
    }
    # 10th frame: if pure strike(s), collapse formatting where appropriate
    if ($frames[9].A -eq "X" -and [string]::IsNullOrWhiteSpace($frames[9].B)) {
        $cell10 = Center "X" $w10
    } else {
        $cell10 = "{0} | {1} | {2}" -f $frames[9].A, $frames[9].B, $frames[9].C
    }
    $balls += (Pad $cell10 $w10) + "│"

    # Score row
    $sc = "│"
    for ($i = 0; $i -lt 9; $i++) {
        $val = if ($i -lt $cum.Count) { [string]$cum[$i] } else { "" }
        $sc += (Center $val $w9) + "│"
    }
    $val10 = if (9 -lt $cum.Count) { [string]$cum[9] } else { "" }
    $sc += (Center $val10 $w10) + "│"

    return ($top + [Environment]::NewLine + $nums + [Environment]::NewLine + $mid + [Environment]::NewLine + $balls + [Environment]::NewLine + $mid + [Environment]::NewLine + $sc + [Environment]::NewLine + $bot)
}

function Show-LaneTalkLastGameScoreboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlayerName,

        [int]$MaxPages = 5
    )

    $gid = Get-LaneTalkLatestGameIdForPlayer -PlayerName $PlayerName -MaxPages $MaxPages
    if (-not $gid) {
        Write-Warning "Couldn't find a recent completed game for '$PlayerName' (scanned $MaxPages page(s))."
        return
    }

    $g = Get-LaneTalkGameDetail -GameId $gid

    $startLocal = $null
    $endLocal   = $null
    if ($g.startTime) { $startLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime) }
    if ($g.endTime)   { $endLocal   = Convert-FromUnixTime -UnixSeconds ([long]$g.endTime) }

    $finalScore = $null
    if ($g.scores) { $finalScore = ($g.scores | Select-Object -Last 1) }
    if ($null -eq $finalScore) { $finalScore = $g.score }

    Write-Host ""
    Write-Host "LaneTalk - Last Game" -ForegroundColor Cyan
    Write-Host ("Player: {0}" -f $g.playerName) -ForegroundColor Yellow
    if ($g.teamName) { Write-Host ("Team:   {0}" -f $g.teamName) }
    Write-Host ("GameId:  {0}  (G{1}  Lane {2})" -f $g.id, $g.game, $g.lane)
    if ($startLocal -and $endLocal) {
        Write-Host ("Time:    {0:MM/dd HH:mm} -> {1:HH:mm}" -f $startLocal, $endLocal)
    }
    if ($null -ne $finalScore) { Write-Host ("Final:   {0}" -f $finalScore) -ForegroundColor Green }
    Write-Host ""

    $sb = Format-LaneTalkScoreboard -Game $g
    Write-Host $sb
}

function Find-LaneTalkPlayers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [int]$MaxPages = 5
    )

    $Query = $Query.Trim()

    # "?" means list all names
    $listAll = ($Query -eq "?")

    if (-not $listAll -and [string]::IsNullOrWhiteSpace($Query)) { return @() }

    # Track earliest (most-recent) occurrence position for each player.
    # Lower rank = newer.
    $rankByKey = @{}
    $nameByKey = @{}

    $rank = 0
    for ($page = 1; $page -le $MaxPages; $page++) {
        $completed = Get-LaneTalkCompleted -Page $page
        if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { break }

        foreach ($c in $completed) {
            $rank++
            if ($null -eq $c.playerName) { continue }

            if ($listAll -or $c.playerName -like "*$Query*") {
                $k = $c.playerName.ToLowerInvariant()
                if (-not $rankByKey.ContainsKey($k)) {
                    $rankByKey[$k] = $rank
                    $nameByKey[$k] = $c.playerName
                }
            }
        }
    }

    $items = foreach ($k in $nameByKey.Keys) {
        [pscustomobject]@{ Name = $nameByKey[$k]; Rank = [int]$rankByKey[$k] }
    }

    # Sort by most-recent first (lowest rank), then name.
    return ($items | Sort-Object Rank, Name | Select-Object -ExpandProperty Name)
}

function Get-LaneTalkPlayerGameIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlayerName,

        [int]$MaxPages = 10
    )

    $PlayerName = $PlayerName.Trim()
    if ([string]::IsNullOrWhiteSpace($PlayerName)) { return @() }

    $ids = New-Object System.Collections.Generic.List[long]

    for ($page = 1; $page -le $MaxPages; $page++) {
        $completed = Get-LaneTalkCompleted -Page $page
        if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { break }

        foreach ($c in $completed) {
            if ($null -eq $c.playerName) { continue }
            if ($c.playerName -eq $PlayerName) {
                if ($c.gameIds) {
                    foreach ($gid in @($c.gameIds)) {
                        try { $ids.Add([long]$gid) | Out-Null } catch { }
                    }
                }
            }
        }
    }

    return ($ids | Select-Object -Unique)
}

function Show-LaneTalkPlayerGamePicker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Search,

        [int]$SearchPages = 5,

        # How many pages to scan for games once player is chosen
        [int]$GamesPages = 10,

        # Don’t hammer the API: only list this many newest games for selection
        [int]$MaxListGames = 20
    )

    # 1) Resolve the player to a single bowler
    $players = Find-LaneTalkPlayers -Query $Search -MaxPages $SearchPages

    if (-not $players -or $players.Count -eq 0) {
        Write-Warning "No bowlers matched '$Search' in the last $SearchPages page(s)."
        return
    }

    # resolved player name
    $playerName = $null

    if ($players.Count -eq 1) {
        # Auto-select
        $playerName = $players[0]
    } else {
        # Page through names, and keep the list sorted by most-recent appearance.
        $pageSize = 20
        $page = 0

        while ($true) {
            $start = $page * $pageSize
            if ($start -ge $players.Count) { $page = 0; $start = 0 }
            $end = [Math]::Min($start + $pageSize - 1, $players.Count - 1)

            Write-Host ""; Write-Host ("Matches (most recent first)  [{0}-{1} of {2}]" -f ($start + 1), ($end + 1), $players.Count) -ForegroundColor Cyan
            for ($i = $start; $i -le $end; $i++) {
                Write-Host (" {0,2}) {1}" -f ($i + 1), $players[$i])
            }

            $prompt = "Select bowler # (n=next, p=prev, 0=cancel)"
            $pickText = Read-Host $prompt

            if ($pickText -eq "0") { return }
            if ($pickText -match "^[Nn]$") { $page++; continue }
            if ($pickText -match "^[Pp]$") { $page = [Math]::Max(0, $page - 1); continue }

            $pick = 0
            if (-not [int]::TryParse($pickText, [ref]$pick)) {
                Write-Warning "Invalid selection."
                continue
            }
            if ($pick -lt 1 -or $pick -gt $players.Count) {
                Write-Warning "Invalid selection."
                continue
            }
            $playerName = $players[$pick - 1]
            break
        }
    }

    # 2) Pull game ids for that exact player name
    $gameIds = @(Get-LaneTalkPlayerGameIds -PlayerName $playerName -MaxPages $GamesPages)

    if (-not $gameIds -or $gameIds.Count -eq 0) {
        Write-Warning "No games found for '$playerName' in the last $GamesPages completed page(s)."
        return
    }

    if ($MaxListGames -gt 0 -and $gameIds.Count -gt $MaxListGames) {
        $gameIds = $gameIds[0..($MaxListGames - 1)]
    }

    # 3) Show options (light metadata per game)
    $options = New-Object System.Collections.Generic.List[object]

    Write-Host ""; Write-Host ("Games for: {0}" -f $playerName) -ForegroundColor Cyan

    for ($i = 0; $i -lt $gameIds.Count; $i++) {
        $gid = $gameIds[$i]
        try {
            $g = Get-LaneTalkGameDetail -GameId $gid

            $startLocal = $null
            if ($g.startTime) { $startLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime) }

            $finalScore = $null
            if ($g.scores) { $finalScore = ($g.scores | Select-Object -Last 1) }
            if ($null -eq $finalScore) { $finalScore = $g.score }

            $options.Add([pscustomobject]@{
                Index = ($i + 1)
                GameId = $g.id
                GameNo = $g.game
                Lane   = $g.lane
                When   = $startLocal
                Score  = $finalScore
                Raw    = $g
            }) | Out-Null

            $whenText = if ($startLocal) { (Get-Date $startLocal -Format "MM/dd HH:mm") } else { "" }
            Write-Host (" {0,2}) G{1}  Lane {2}  Score {3}  {4}  (GameId {5})" -f ($i + 1), $g.game, $g.lane, $finalScore, $whenText, $g.id)
        } catch {
            Write-Host (" {0,2}) (GameId {1} failed to load)" -f ($i + 1), $gid) -ForegroundColor DarkYellow
        }
    }

    Write-Host ""

    # Auto-select if there's only one game in the list
    if ($options.Count -eq 1) {
        $chosen = $options[0]
    } else {
        $selText = Read-Host "Pick a game number to display (or 0 to cancel)"
        $sel = 0
        if (-not [int]::TryParse($selText, [ref]$sel)) {
            Write-Warning "Invalid selection."
            return
        }

        if ($sel -eq 0) { return }
        if ($sel -lt 1 -or $sel -gt $options.Count) {
            Write-Warning "Invalid selection."
            return
        }

        $chosen = $options[$sel - 1]
    }

    Write-Host ""
    Write-Host "LaneTalk - Game Scoreboard" -ForegroundColor Cyan
    Write-Host ("Player: {0}" -f $chosen.Raw.playerName) -ForegroundColor Yellow
    if ($chosen.Raw.teamName) { Write-Host ("Team:   {0}" -f $chosen.Raw.teamName) }
    Write-Host ("GameId:  {0}  (G{1}  Lane {2})" -f $chosen.GameId, $chosen.GameNo, $chosen.Lane)
    if ($chosen.When) { Write-Host ("When:   {0:MM/dd/yyyy HH:mm}" -f $chosen.When) }
    if ($null -ne $chosen.Score) { Write-Host ("Score:  {0}" -f $chosen.Score) -ForegroundColor Green }
    Write-Host ""

    $sb = Format-LaneTalkScoreboard -Game $chosen.Raw
    Write-Host $sb
}



function Get-LaneTalkGameDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long]$GameId
    )

    $headers = @{
        apiKey  = $script:LaneTalkApiKey
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

function Format-LaneTalkFrames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Game
    )

    # LaneTalk scorecard data tends to be arrays representing progression.
    # We try to present something human-readable without assuming too much.
    $scores = @()
    $throws = @()
    $pins   = @()

    if ($Game.scores) { $scores = @($Game.scores) }
    if ($Game.throws) { $throws = @($Game.throws) }
    if ($Game.pins)   { $pins   = @($Game.pins) }

    # Build a compact 10-frame-ish view. If the API provides more/less, we still show what we have.
    $lines = New-Object System.Collections.Generic.List[string]

    if ($scores.Count -gt 0) {
        $lines.Add("Scores (progression):") | Out-Null
        for ($i = 0; $i -lt $scores.Count; $i++) {
            $lines.Add((" {0,2}: {1}" -f $i, $scores[$i])) | Out-Null
        }
    }

    if ($throws.Count -gt 0) {
        $lines.Add("") | Out-Null
        $lines.Add("Throws:") | Out-Null
        for ($i = 0; $i -lt $throws.Count; $i++) {
            $lines.Add((" {0,2}: {1}" -f $i, $throws[$i])) | Out-Null
        }
    }

    if ($pins.Count -gt 0) {
        $lines.Add("") | Out-Null
        $lines.Add("Pins:") | Out-Null
        for ($i = 0; $i -lt $pins.Count; $i++) {
            $lines.Add((" {0,2}: {1}" -f $i, $pins[$i])) | Out-Null
        }
    }

    return ($lines -join [Environment]::NewLine)
}

function Get-LaneTalkLatestGameIdForPlayer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlayerName,

        # How many /completed pages to scan (page 1 is newest)
        [int]$MaxPages = 3
    )

    $PlayerName = $PlayerName.Trim()
    if ([string]::IsNullOrWhiteSpace($PlayerName)) {
        return $null
    }

    for ($page = 1; $page -le $MaxPages; $page++) {
        $completed = Get-LaneTalkCompleted -Page $page
        if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { break }

        foreach ($c in $completed) {
            if ($null -eq $c.playerName) { continue }

            # same matching semantics as the rest of the app
            if ($c.playerName -like "*$PlayerName*") {
                if ($c.gameIds -and @($c.gameIds).Count -gt 0) {
                    # /completed appears newest-first. Take the first matching row's first gameId.
                    return [long](@($c.gameIds)[0])
                }
            }
        }
    }

    return $null
}





function Start-LaneTalkMenu {
    while ($true) {
        Write-Host ""
        Write-Host "LaneTalk" -ForegroundColor Cyan

        $center = $null
        try { $center = Get-LaneTalkCenterStatus -CacheSeconds 60 } catch { }

        Write-Host "CenterId: $($script:LaneTalkCenterId)" -ForegroundColor DarkCyan

        if ($center) {
            # Print what we have without assuming every property exists
            $name = $center.companyName
            if (-not $name) { $name = $center.name }
            if ($name) { Write-Host ("Center:  {0}" -f $name) -ForegroundColor DarkCyan }

            $loc = $center.location
            if (-not $loc) {
                $parts = @($center.city, $center.state)
                $loc = (($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", ")
            }
            if ($loc) { Write-Host ("Location:{0,2}{1}" -f "", $loc) -ForegroundColor DarkCyan }

            if ($null -ne $center.lanes) { Write-Host ("Lanes:   {0}" -f $center.lanes) -ForegroundColor DarkCyan }

            # Active games: trust center.activeGames only if it looks sane (<= lanes). Otherwise fall back to a "recent" count.
            $activeOk = $false
            $active = $null
            if ($null -ne $center.activeGames -and $null -ne $center.lanes) {
                try {
                    $active = [int]$center.activeGames
                    if ($active -le [int]$center.lanes) { $activeOk = $true }
                } catch { }
            }

            if ($activeOk) {
                Write-Host ("Active:  {0}" -f $active) -ForegroundColor DarkCyan
            } else {
                try {
                    $recent = (Get-LaneTalkCompleted -Page 1 | Measure-Object).Count
                    Write-Host ("Recent:  {0} (completed page 1)" -f $recent) -ForegroundColor DarkCyan
                } catch {
                    # nothing
                }
            }

            if ($center.postalCode) { Write-Host ("Postal:  {0}" -f $center.postalCode) -ForegroundColor DarkCyan }
            if ($center.country)    { Write-Host ("Country: {0}" -f $center.country) -ForegroundColor DarkCyan }
        }

        Write-Host ""
        Write-Host " 1) One-shot scoreboard (Page 1)"
        Write-Host " 2) Search bowler and pick a game (scoreboard)"
        Write-Host " 5) Export Page 1 (playerName,lane,gameScores) to CSV"
        Write-Host " 0) Exit"
        Write-Host ""

        $choice = Read-Host "Select option"
        switch ($choice) {
            "1" { Show-LaneTalkHydratedScoreboardOnce -Page 1 -SleepMs 25 -MaxGames 5000 }
            "2" {
                $search = Read-Host "Search bowler name (type ? to list all)"
                if ([string]::IsNullOrWhiteSpace($search)) {
                    Write-Warning "Search was empty."
                } else {
                    Show-LaneTalkPlayerGamePicker -Search $search
                }
            }
            "5" {
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

# Auto-launch menu (but make failures obvious)
Write-Host "" 
Write-Host "[LaneTalk] Script loaded. Starting menu..." -ForegroundColor DarkGray

try {
    Start-LaneTalkMenu
} catch {
    Write-Host "" 
    Write-Host "[LaneTalk] FATAL: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_ -ForegroundColor DarkRed
    try { Read-Host "Press Enter to close" | Out-Null } catch { }
}
