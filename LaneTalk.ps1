# =========================
# LaneTalk (Bowler Loop)
# =========================
# - No menu.
# - Always: search bowler -> pick game -> view scoreboard -> repeat until quit.
# - Supports:
#     ?                 = list all names (from recent pages)
#     name@YYYY-MM-DD   = expand page scan to reach that date
#     In game picker:
#        m = more games, a = show all scoreboards, 0 = back
#
# Hardcoded Center ID (as requested)
$script:LaneTalkCenterId = "eb0f0b49-b676-430a-9a69-86bf9638b6b1"

# Put the key that makes your OG curl work RIGHT HERE.
# If LaneTalk rotates it later, update this string.
$script:LaneTalkApiKey = "8tLtPc8UwWvdvbpzRIr0ifCWy250TXUXrGUn"

function Convert-FromUnixTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][long]$UnixSeconds,
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
        [ValidateSet('GET','POST')][string]$Method = 'GET',
        [object]$Body = $null
    )

    $headers = @{
        # PowerShell hashtable keys are case-insensitive, so we can't include both apikey + apiKey.
        # The web app uses "apiKey".
        apiKey  = $script:LaneTalkApiKey
        accept  = 'application/json'
        origin  = 'https://livescores.lanetalk.com'
        referer = 'https://livescores.lanetalk.com/'
    }

    if ($Method -eq 'POST') {
        $json = $Body | ConvertTo-Json -Depth 30
        return Invoke-RestMethod -Method POST -Uri $Uri -Headers $headers -Body $json -ContentType 'application/json' -TimeoutSec 30
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
        [int]$CacheSeconds = 60,
        [switch]$Force,
        [switch]$Quiet
    )

    if (-not $Force -and $script:LaneTalkCenterStatusCache -and $script:LaneTalkCenterStatusCache.When) {
        $age = (New-TimeSpan -Start $script:LaneTalkCenterStatusCache.When -End (Get-Date)).TotalSeconds
        if ($age -lt $CacheSeconds -and $script:LaneTalkCenterStatusCache.Data) {
            return $script:LaneTalkCenterStatusCache.Data
        }
    }

    $centerId = $script:LaneTalkCenterId

    $candidates = @(
        "https://api.lanetalk.com/v1/bowlingcenters/$centerId"
        
    )

    function Invoke-LaneTalkApi-Variant {
        param(
            [Parameter(Mandatory)][string]$Uri,
            [Parameter(Mandatory)][ValidateSet('apikey','apiKey')][string]$HeaderName
        )

        $headers = @{
            $HeaderName = $script:LaneTalkApiKey
            accept      = 'application/json'
            origin      = 'https://livescores.lanetalk.com'
            referer     = 'https://livescores.lanetalk.com/'
        }

        Invoke-RestMethod -Method GET -Uri $Uri -Headers $headers -TimeoutSec 30
    }

    $data = $null
    $current = $null
    $urlUsed = $null
    $lastError = $null

    foreach ($u in $candidates) {
        foreach ($hn in @('apikey','apiKey')) {
            try {
                $data = Invoke-LaneTalkApi-Variant -Uri $u -HeaderName $hn
                if (-not $data) { continue }

                $candidateCurrent = $null
                if ($data.state -and $data.state.current) {
                    $candidateCurrent = $data.state.current
                } elseif ($data.current) {
                    $candidateCurrent = $data.current
                } else {
                    $candidateCurrent = $data
                }

                $current = $candidateCurrent
                $urlUsed = "$u (header=$hn)"
                break
            } catch {
                $lastError = $_
                continue
            }
        }
        if ($current) { break }
    }

    $script:LaneTalkCenterStatusCache = [pscustomobject]@{
        When     = Get-Date
        Data     = $current
        Raw      = $data
        UrlUsed  = $urlUsed
        UrlTried = ($candidates -join '; ')
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
        [Parameter(Mandatory)][object]$Game
    )

    $throws = @()
    $scores = @()

    if ($Game.throws) { $throws = @($Game.throws) }
    if ($Game.scores) { $scores = @($Game.scores) }

    $throws = $throws | ForEach-Object { if ($null -eq $_) { "" } else { [string]$_ } }
    $scores = $scores | ForEach-Object { if ($null -eq $_) { "" } else { [string]$_ } }

    function Convert-LaneTalkThrow([string]$t) {
        if ($null -eq $t) { $t = "" }
        $t = $t.Trim()
        if ($t -eq "") { return "" }
        if ($t -eq "0") { return "-" }
        return $t
    }

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

    $w9  = 7
    $w10 = 11

    $top = "┌" + (("─" * $w9 + "┬") * 9) + ("─" * $w10) + "┐"
    $mid = "├" + (("─" * $w9 + "┼") * 9) + ("─" * $w10) + "┤"
    $bot = "└" + (("─" * $w9 + "┴") * 9) + ("─" * $w10) + "┘"

    $nums = "│"
    for ($i = 1; $i -le 9; $i++) { $nums += (Center ([string]$i) $w9) + "│" }
    $nums += (Center "10" $w10) + "│"

    $balls = "│"
    for ($i = 0; $i -lt 9; $i++) {
        $a = $frames[$i].A
        $b = $frames[$i].B

        if ($a -eq "X" -and [string]::IsNullOrWhiteSpace($b)) {
            $balls += (Center "X" $w9) + "│"
        } else {
            $balls += (Pad ("{0} | {1}" -f $a, $b) $w9) + "│"
        }
    }

    $cell10 = if ($frames[9].A -eq "X" -and [string]::IsNullOrWhiteSpace($frames[9].B)) { Center "X" $w10 } else { "{0} | {1} | {2}" -f $frames[9].A, $frames[9].B, $frames[9].C }
    $balls += (Pad $cell10 $w10) + "│"

    $sc = "│"
    for ($i = 0; $i -lt 9; $i++) {
        $val = if ($i -lt $cum.Count) { [string]$cum[$i] } else { "" }
        $sc += (Center $val $w9) + "│"
    }
    $val10 = if (9 -lt $cum.Count) { [string]$cum[9] } else { "" }
    $sc += (Center $val10 $w10) + "│"

    return ($top + [Environment]::NewLine + $nums + [Environment]::NewLine + $mid + [Environment]::NewLine + $balls + [Environment]::NewLine + $mid + [Environment]::NewLine + $sc + [Environment]::NewLine + $bot)
}

function Find-LaneTalkPlayers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [int]$MaxPages = 5
    )

    $Query = $Query.Trim()
    $listAll = ($Query -eq '?')

    if (-not $listAll -and [string]::IsNullOrWhiteSpace($Query)) { return @() }

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

    return ($items | Sort-Object Rank, Name | Select-Object -ExpandProperty Name)
}

function Get-LaneTalkPlayerGameIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PlayerName,
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

function Get-LaneTalkGameDetail {
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$GameId)

    $headers = @{
        apiKey  = $script:LaneTalkApiKey
        accept  = 'application/json'
        origin  = 'https://livescores.lanetalk.com'
        referer = 'https://livescores.lanetalk.com/'
    }

    $candidates = @(
        "https://api.lanetalk.com/v1/scorecards/games/$GameId"
    )

    foreach ($u in $candidates) {
        try { return Invoke-RestMethod -Method GET -Uri $u -Headers $headers -ErrorAction Stop } catch { }
    }

    throw "No candidate game-detail endpoints returned 200 for GameId=$GameId"
}

function Resolve-LaneTalkPagesForDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime]$Since,
        [int]$MaxPages = 200,
        [int]$SampleRowsPerPage = 3,
        [int]$SleepMs = 25
    )

    for ($page = 1; $page -le $MaxPages; $page++) {
        $completed = Get-LaneTalkCompleted -Page $page
        if (-not $completed -or ($completed | Measure-Object).Count -eq 0) { return $page }

        $rows = @($completed)
        $take = [Math]::Min($SampleRowsPerPage, $rows.Count)
        $sample = @($rows | Select-Object -Last $take)

        $oldest = $null

        foreach ($c in $sample) {
            if (-not $c.gameIds -or @($c.gameIds).Count -eq 0) { continue }
            $gid = [long](@($c.gameIds)[0])

            try {
                $g = Get-LaneTalkGameDetail -GameId $gid
                if ($g.startTime) {
                    $dt = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime)
                    if ($dt) {
                        if ($null -eq $oldest -or $dt -lt $oldest) { $oldest = $dt }
                    }
                }
            } catch { }

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        if ($null -eq $oldest) { continue }
        if ($oldest -lt $Since) { return $page }
    }

    return $MaxPages
}

function Show-LaneTalkPlayerGamePicker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Search,
        [int]$SearchPages = 5,
        [int]$GamesPages = 10,
        [int]$MaxListGames = 20
    )

    $players = @(Find-LaneTalkPlayers -Query $Search -MaxPages $SearchPages)
    if (-not $players -or $players.Count -eq 0) {
        Write-Warning "No bowlers matched '$Search' in the last $SearchPages page(s)."
        return
    }

    $playerName = $null

    if ($players.Count -eq 1) {
        $playerName = $players[0]
    } else {
        $pageSize = 20
        $page = 0

        while ($true) {
            $start = $page * $pageSize
            if ($start -ge $players.Count) { $page = 0; $start = 0 }
            $end = [Math]::Min($start + $pageSize - 1, $players.Count - 1)

            Write-Host ""; Write-Host ("Matches (most recent first)  [{0}-{1} of {2}]" -f ($start + 1), ($end + 1), $players.Count) -ForegroundColor Cyan
            for ($i = $start; $i -le $end; $i++) { Write-Host (" {0,2}) {1}" -f ($i + 1), $players[$i]) }

            $pickText = Read-Host "Select bowler # (n=next, p=prev, 0=cancel)"

            if ($pickText -eq '0') { return }
            if ($pickText -match '^[Nn]$') { $page++; continue }
            if ($pickText -match '^[Pp]$') { $page = [Math]::Max(0, $page - 1); continue }

            $pick = 0
            if (-not [int]::TryParse($pickText, [ref]$pick)) { Write-Warning 'Invalid selection.'; continue }
            if ($pick -lt 1 -or $pick -gt $players.Count) { Write-Warning 'Invalid selection.'; continue }

            $playerName = $players[$pick - 1]
            break
        }
    }

    # We'll progressively scan further back when the user hits 'm'
    $gamesPagesCurrent = [int]$GamesPages
    $allGameIds = @(Get-LaneTalkPlayerGameIds -PlayerName $playerName -MaxPages $gamesPagesCurrent)
    if (-not $allGameIds -or $allGameIds.Count -eq 0) {
        Write-Warning "No games found for '$playerName' in the last $GamesPages completed page(s)."
        return
    }

    $listCount = if ($MaxListGames -gt 0) { [Math]::Min($MaxListGames, $allGameIds.Count) } else { $allGameIds.Count }

    function Build-LaneTalkGameOptions {
        param([long[]]$Ids)

        $opts = New-Object System.Collections.Generic.List[object]

        Write-Host ""; Write-Host ("Games for: {0}  (showing {1}/{2})" -f $playerName, $Ids.Count, $allGameIds.Count) -ForegroundColor Cyan

        for ($i = 0; $i -lt $Ids.Count; $i++) {
            $gid = $Ids[$i]
            try {
                $g = Get-LaneTalkGameDetail -GameId $gid

                $startLocal = $null
                if ($g.startTime) { $startLocal = Convert-FromUnixTime -UnixSeconds ([long]$g.startTime) }

                $finalScore = $null
                if ($g.scores) { $finalScore = ($g.scores | Select-Object -Last 1) }
                if ($null -eq $finalScore) { $finalScore = $g.score }

                $opts.Add([pscustomobject]@{
                    Index  = ($i + 1)
                    GameId = $g.id
                    GameNo = $g.game
                    Lane   = $g.lane
                    When   = $startLocal
                    Score  = $finalScore
                    Raw    = $g
                }) | Out-Null

                $whenText = if ($startLocal) { (Get-Date $startLocal -Format 'MM/dd HH:mm') } else { '' }
                Write-Host (" {0,2}) G{1}  Lane {2}  Score {3}  {4}  (GameId {5})" -f ($i + 1), $g.game, $g.lane, $finalScore, $whenText, $g.id)
            } catch {
                Write-Host (" {0,2}) (GameId {1} failed to load)" -f ($i + 1), $gid) -ForegroundColor DarkYellow
            }
        }

        return $opts
    }

    function Show-LaneTalkGameScoreboardFromOption {
        param([Parameter(Mandatory)][object]$Opt)

        Write-Host ""
        Write-Host 'LaneTalk - Game Scoreboard' -ForegroundColor Cyan
        Write-Host ("Player: {0}" -f $Opt.Raw.playerName) -ForegroundColor Yellow
        if ($Opt.Raw.teamName) { Write-Host ("Team:   {0}" -f $Opt.Raw.teamName) }
        Write-Host ("GameId:  {0}  (G{1}  Lane {2})" -f $Opt.GameId, $Opt.GameNo, $Opt.Lane)
        if ($Opt.When) { Write-Host ("When:   {0:MM/dd/yyyy HH:mm}" -f $Opt.When) }
        if ($null -ne $Opt.Score) { Write-Host ("Score:  {0}" -f $Opt.Score) -ForegroundColor Green }
        Write-Host ""

        Write-Host (Format-LaneTalkScoreboard -Game $Opt.Raw)
    }

    while ($true) {
        $idsToShow = @($allGameIds[0..($listCount - 1)])
        $options = Build-LaneTalkGameOptions -Ids $idsToShow

        Write-Host ""
        if ($options.Count -eq 1) {
            Show-LaneTalkGameScoreboardFromOption -Opt $options[0]
        } else {
            $selText = Read-Host 'Pick game # (a=all, m=more, 0=back)'

            if ($selText -eq '0') { return }

            if ($selText -match '^[Aa]$') {
                Write-Host ""; Write-Host ("Showing ALL {0} games loaded..." -f $options.Count) -ForegroundColor Cyan
                for ($i = 0; $i -lt $options.Count; $i++) {
                    Write-Host ""; Write-Host ("==== {0}/{1} ====" -f ($i + 1), $options.Count) -ForegroundColor DarkCyan
                    Show-LaneTalkGameScoreboardFromOption -Opt $options[$i]
                }
            } elseif ($selText -match '^[Mm]$') {
                # "m" first shows more of what we've already scanned; once exhausted,
                # it scans further back (more /completed pages) and adds any newly found games.
                if ($listCount -lt $allGameIds.Count) {
                    $listCount = [Math]::Min($allGameIds.Count, $listCount + $MaxListGames)
                } else {
                    $prevCount = $allGameIds.Count
                    $gamesPagesCurrent += [Math]::Max(1, $GamesPages)

                    # Hard safety cap (don't let this run forever)
                    $hardCap = 200
                    if ($gamesPagesCurrent -gt $hardCap) { $gamesPagesCurrent = $hardCap }

                    Write-Host ("Scanning further back (now {0} completed page(s))..." -f $gamesPagesCurrent) -ForegroundColor DarkGray

                    $moreIds = @(Get-LaneTalkPlayerGameIds -PlayerName $playerName -MaxPages $gamesPagesCurrent)
                    if ($moreIds.Count -gt 0) {
                        $allGameIds = @($moreIds | Select-Object -Unique)
                    }

                    if ($allGameIds.Count -le $prevCount) {
                        Write-Host 'No more games found in the older pages scanned.' -ForegroundColor DarkYellow
                    } else {
                        # After expanding the universe, show the next chunk.
                        $listCount = [Math]::Min($allGameIds.Count, $listCount + $MaxListGames)
                    }
                }
                continue
            } else {
                $sel = 0
                if (-not [int]::TryParse($selText, [ref]$sel)) { Write-Warning 'Invalid selection.'; continue }
                if ($sel -lt 1 -or $sel -gt $options.Count) { Write-Warning 'Invalid selection.'; continue }

                Show-LaneTalkGameScoreboardFromOption -Opt $options[$sel - 1]
            }
        }

        Write-Host ""
        $again = Read-Host 'Show another game for this bowler? (y/n)'
        if ($again -match '^[Yy]$') { continue }
        return
    }
}

function Start-LaneTalkBowlerLoop {
    [CmdletBinding()]
    param(
        [int]$DefaultPages = 5,
        [int]$MaxPagesCap = 60
    )

    while ($true) {
        Write-Host ""
        Write-Host 'LaneTalk' -ForegroundColor Cyan

        $center = $null
        try { $center = Get-LaneTalkCenterStatus -CacheSeconds 300 -Quiet } catch { $center = $null }

        if ($center) {
            $name = $center.companyName
            if (-not $name) { $name = $center.name }
            if ($name) { Write-Host ("Center:  {0}" -f $name) -ForegroundColor DarkCyan }

            if ($center.address) { Write-Host ("Address: {0}" -f $center.address) -ForegroundColor DarkCyan }
            if ($center.url)     { Write-Host ("URL:     {0}" -f $center.url) -ForegroundColor DarkCyan }

            if ($null -ne $center.lanes) { Write-Host ("Lanes:   {0}" -f $center.lanes) -ForegroundColor DarkCyan }
            if ($null -ne $center.activePlayers) { Write-Host ("Players: {0}" -f $center.activePlayers) -ForegroundColor DarkCyan }
        }

        Write-Host ""
        Write-Host 'Search bowler (enter to quit)'
        Write-Host ' - ?                = list all names (recent pages)'
        Write-Host ' - name@YYYY-MM-DD  = expand scan to reach that date' -ForegroundColor DarkGray
        Write-Host ""

        $input = Read-Host 'Bowler'
        if ([string]::IsNullOrWhiteSpace($input)) { return }

        $search = $input.Trim()
        if ($search -match '^(0|q|quit|exit)$') { return }

        $pages = $DefaultPages

        if ($search -match '^(?<q>.+?)@(?<d>\d{4}-\d{2}-\d{2})$') {
            $search = $Matches.q.Trim()
            try {
                $since = [datetime]::ParseExact($Matches.d, 'yyyy-MM-dd', $null)
                $pages = Resolve-LaneTalkPagesForDate -Since $since -MaxPages $MaxPagesCap -SampleRowsPerPage 3 -SleepMs 25
            } catch {
                Write-Warning "Couldn't parse date. Use YYYY-MM-DD."
                $pages = $DefaultPages
            }
        }

        if ($pages -gt $MaxPagesCap) { $pages = $MaxPagesCap }

        Show-LaneTalkPlayerGamePicker -Search $search -SearchPages $pages -GamesPages $pages -MaxListGames 20
    }
}

function Start-LaneTalkMenu {
    Start-LaneTalkBowlerLoop
}

Write-Host ""
Write-Host '[LaneTalk] Script loaded. Starting bowler search...' -ForegroundColor DarkGray

try {
    Start-LaneTalkBowlerLoop
} catch {
    Write-Host ""
    Write-Host ("[LaneTalk] FATAL: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host $_.ToString() -ForegroundColor DarkRed
    try { Read-Host 'Press Enter to close' | Out-Null } catch { }
}
