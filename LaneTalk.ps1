# =========================
# LaneTalk LiveScores Helper
# - Auto-extract REST apiKey from JS (cached)
# - Fetch completed results
# - Fetch blocks search (uuid works)
# - Fetch game details (BINGO: includes lane, frames, pins, etc.)
# - Hydrate + group by bowler with nested games
# - Export to CSV (including nested games as JSON)
# - Interactive menu auto-launch
# =========================

# ---- HARD-CODED CENTER ID (as requested) ----
$script:LaneTalkCenterId = [Guid]"eb0f0b49-b676-430a-9a69-86bf9638b6b1"

# -------------------------
# Cache helpers
# -------------------------
function Get-LaneTalkCachePath {
    [CmdletBinding()]
    param([string]$Name)

    $dir = Join-Path $env:LOCALAPPDATA "LaneTalk"
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    Join-Path $dir $Name
}

function Read-JsonCache {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return $null }
    try { (Get-Content -Path $Path -Raw -ErrorAction Stop) | ConvertFrom-Json -ErrorAction Stop }
    catch { $null }
}

function Write-JsonCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Object
    )
    $Object | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

# -------------------------
# JS scraping (apiKey extraction)
# -------------------------
function Get-LaneTalkJsAssetUrls {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LiveScoresUrl)

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    $base = [Uri]$LiveScoresUrl
    $origin = "{0}://{1}" -f $base.Scheme, $base.Host

    $html = (Invoke-WebRequest -Uri $LiveScoresUrl -Headers @{
        "User-Agent" = $ua
        "Accept"     = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    } -Method GET -MaximumRedirection 5 -TimeoutSec 30).Content

    if (-not $html) { throw "LiveScores HTML was empty." }

    $matches = [regex]::Matches($html, '(?<path>/assets/[^"''\s>]+\.js)', 'IgnoreCase')
    if ($matches.Count -lt 1) { throw "Could not find any /assets/*.js references in the LiveScores HTML." }

    $matches |
        ForEach-Object { "$origin$($_.Groups['path'].Value)" } |
        Select-Object -Unique
}

function Extract-LaneTalkApiKeyFromJs {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$JsContent)

    $patterns = @(
        'headers\.apiKey\s*=\s*"(?<k>[^"]+)"',
        'headers\.apikey\s*=\s*"(?<k>[^"]+)"',
        '["'']apiKey["'']\s*:\s*["''](?<k>[^"''\s]+)["'']',
        '["'']apikey["'']\s*:\s*["''](?<k>[^"''\s]+)["'']'
    )

    foreach ($pat in $patterns) {
        $m = [regex]::Match($JsContent, $pat, 'IgnoreCase')
        if ($m.Success -and $m.Groups['k'].Value) { return $m.Groups['k'].Value }
    }

    return $null
}

function Get-LaneTalkLiveScoresApiKey {
<#
.SYNOPSIS
    Gets the LaneTalk LiveScores frontend REST API key by scraping the JS bundle, with caching.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LiveScoresUrl,
        [int]$CacheTtlHours = 168,
        [switch]$ForceRefresh
    )

    $cachePath = Get-LaneTalkCachePath -Name "lanetalk_rest_apikey.json"
    $cached = Read-JsonCache -Path $cachePath

    if (-not $ForceRefresh -and $cached -and $cached.apiKey) {
        try {
            $cachedAt = [datetime]::Parse($cached.cachedAt)
            if ((Get-Date) -lt $cachedAt.AddHours($CacheTtlHours)) {
                return $cached.apiKey
            }
        } catch {}
    }

    $assetUrls = Get-LaneTalkJsAssetUrls -LiveScoresUrl $LiveScoresUrl

    # Prefer index bundle first (usually where constants live)
    $ordered = @(
        $assetUrls | Where-Object { $_ -match '/assets/index' }
        $assetUrls | Where-Object { $_ -notmatch '/assets/index' }
    ) | Select-Object -Unique

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    foreach ($jsUrl in $ordered) {
        try {
            $js = (Invoke-WebRequest -Uri $jsUrl -Headers @{
                "User-Agent" = $ua
                "Accept"     = "application/javascript,text/javascript,*/*;q=0.8"
                "Referer"    = "https://livescores.lanetalk.com/"
            } -Method GET -TimeoutSec 30).Content

            $key = Extract-LaneTalkApiKeyFromJs -JsContent $js
            if ($key) {
                Write-JsonCache -Path $cachePath -Object ([pscustomobject]@{
                    apiKey      = $key
                    cachedAt    = (Get-Date).ToString("o")
                    cachedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
                })
                return $key
            }
        } catch { continue }
    }

    throw "Failed to extract LaneTalk REST API key from JS assets. Frontend structure may have changed."
}

# -------------------------
# Core API invoker (REST)
# -------------------------
function Invoke-LaneTalkApi {
<#
.SYNOPSIS
    Calls a LaneTalk API endpoint using an auto-extracted REST API key.
    If 401/403, force refresh key once and retry.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$LiveScoresUrl,
        [ValidateSet("GET","POST")][string]$Method = "GET",
        [object]$Body = $null
    )

    $apiKey = Get-LaneTalkLiveScoresApiKey -LiveScoresUrl $LiveScoresUrl

    $headers = @{
        accept       = "application/json"
        apikey       = $apiKey
        origin       = "https://livescores.lanetalk.com"
        referer      = "https://livescores.lanetalk.com/"
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    $invoke = {
        param($u,$m,$h,$b)
        if ($null -ne $b) {
            Invoke-RestMethod -Method $m -Uri $u -Headers $h -Body ($b | ConvertTo-Json -Depth 20) -ContentType "application/json" -TimeoutSec 30
        } else {
            Invoke-RestMethod -Method $m -Uri $u -Headers $h -TimeoutSec 30
        }
    }

    try {
        & $invoke $Uri $Method $headers $Body
    } catch {
        $statusCode = $null
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}

        if ($statusCode -in 401,403) {
            $apiKey = Get-LaneTalkLiveScoresApiKey -LiveScoresUrl $LiveScoresUrl -ForceRefresh
            $headers.apikey = $apiKey
            return & $invoke $Uri $Method $headers $Body
        }
        throw
    }
}

# -------------------------
# REST endpoints
# -------------------------
function Get-LaneTalkCompleted {
<#
.SYNOPSIS
    Gets completed results page for the hardcoded center.
#>
    [CmdletBinding()]
    param([int]$Page = 1)

    $centerId = $script:LaneTalkCenterId
    $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId?tab=finished&q=&order=date&sort=asc"
    $uri = "https://api.lanetalk.com/v1/bowlingcenters/$centerId/completed/$Page"

    Invoke-LaneTalkApi -Uri $uri -LiveScoresUrl $liveScoresUrl -Method GET
}

function Search-LaneTalkFinishedBlocks {
<#
.SYNOPSIS
    Searches finished scorecard blocks for the hardcoded center (uuid is required).
#>
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$PageSize = 50
    )

    $centerId = $script:LaneTalkCenterId
    $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId"
    $uri = "https://api.lanetalk.com/v1/scorecards/blocks/search"

    $body = @{
        uuid     = "$centerId"
        page     = $Page
        pageSize = $PageSize
    }

    Invoke-LaneTalkApi -Uri $uri -LiveScoresUrl $liveScoresUrl -Method POST -Body $body
}

function Get-LaneTalkGameDetail {
<#
.SYNOPSIS
    Gets detailed telemetry for a single gameId (includes lane, frames, pins, etc.).
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$GameId)

    $centerId = $script:LaneTalkCenterId
    $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId"
    $uri = "https://api.lanetalk.com/v1/games/$GameId"

    Invoke-LaneTalkApi -Uri $uri -LiveScoresUrl $liveScoresUrl -Method GET
}

# -------------------------
# Display helpers
# -------------------------
function Format-LaneTalkGameScores {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$Values)
    process {
        if ($null -eq $Values) { return "" }
        if ($Values -is [System.Collections.IEnumerable] -and -not ($Values -is [string])) { return (@($Values) -join ",") }
        return "$Values"
    }
}

function Show-LaneTalkCompletedScoreboardOnce {
    [CmdletBinding()]
    param([int]$Page = 1)

    $data = Get-LaneTalkCompleted -Page $Page

    $data |
        Sort-Object totalScore -Descending |
        Select-Object playerName, teamName, totalScore,
            @{n="gameScores"; e={ Format-LaneTalkGameScores $_.gameScores }} |
        Format-Table -AutoSize
}

function Watch-LaneTalkCompletedScoreboard {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$PollSeconds = 5
    )

    $lastModified = 0

    while ($true) {
        $data = Get-LaneTalkCompleted -Page $Page
        $maxModified = ($data | Measure-Object modified -Maximum).Maximum

        if ($maxModified -gt $lastModified) {
            $lastModified = $maxModified
            Clear-Host
            Get-Date
            $data |
                Sort-Object totalScore -Descending |
                Select-Object playerName, teamName, totalScore,
                    @{n="gameScores"; e={ Format-LaneTalkGameScores $_.gameScores }} |
                Format-Table -AutoSize
        }

        Start-Sleep -Seconds $PollSeconds
    }
}

function Show-LaneTalkFinishedBlocksRaw {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$PageSize = 5
    )

    $resp = Search-LaneTalkFinishedBlocks -Page $Page -PageSize $PageSize
    $resp | Format-List *
}

function Show-LaneTalkGameDetailRaw {
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$GameId)

    (Get-LaneTalkGameDetail -GameId $GameId) | Format-List *
}

# -------------------------
# Export helpers (CSV)
# -------------------------
function Export-LaneTalkCompletedToCsv {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [Parameter(Mandatory)][string]$Path
    )

    $data = Get-LaneTalkCompleted -Page $Page

    $out = $data | Select-Object `
        playerName,
        teamName,
        totalScore,
        @{n="gameScores"; e={ Format-LaneTalkGameScores $_.gameScores }},
        @{n="gameIds"; e={ Format-LaneTalkGameScores $_.gameIds }},
        modified,
        blockId

    $out | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($out.Count) rows to: $Path" -ForegroundColor Green
}

function Export-LaneTalkCompletedAllToCsv {
<#
.SYNOPSIS
    Exports ALL completed pages to a single CSV by paging /completed/<n> until empty.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$StartPage = 1,
        [int]$MaxPages = 500,
        [int]$SleepMs = 200
    )

    $all = New-Object System.Collections.Generic.List[object]

    for ($page = $StartPage; $page -le $MaxPages; $page++) {
        Write-Host "Fetching completed page $page..." -ForegroundColor DarkCyan
        $data = Get-LaneTalkCompleted -Page $page

        $count = 0
        try { $count = ($data | Measure-Object).Count } catch { $count = 0 }
        if ($count -eq 0) { Write-Host "No results on page $page. Stopping." -ForegroundColor DarkCyan; break }

        foreach ($r in $data) {
            $all.Add([pscustomobject]@{
                playerName = $r.playerName
                teamName   = $r.teamName
                totalScore = $r.totalScore
                gameScores = (Format-LaneTalkGameScores $r.gameScores)
                gameIds    = (Format-LaneTalkGameScores $r.gameIds)
                modified   = $r.modified
                blockId    = $r.blockId
            }) | Out-Null
        }

        Start-Sleep -Milliseconds $SleepMs
    }

    $all | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($all.Count) rows to: $Path" -ForegroundColor Green
}

function Export-LaneTalkFinishedBlocksToCsv {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$PageSize = 200,
        [Parameter(Mandatory)][string]$Path
    )

    $data = Search-LaneTalkFinishedBlocks -Page $Page -PageSize $PageSize
    $data | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported blocks search page $Page to: $Path" -ForegroundColor Green
}

function Export-LaneTalkFinishedBlocksAllToCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$StartPage = 1,
        [int]$PageSize = 200,
        [int]$MaxPages = 500,
        [int]$SleepMs = 200
    )

    $all = New-Object System.Collections.Generic.List[object]

    for ($page = $StartPage; $page -le $MaxPages; $page++) {
        Write-Host "Fetching blocks search page $page..." -ForegroundColor DarkCyan
        $data = Search-LaneTalkFinishedBlocks -Page $page -PageSize $PageSize

        $count = 0
        try { $count = ($data | Measure-Object).Count } catch { $count = 0 }
        if ($count -eq 0) { Write-Host "No results on page $page. Stopping." -ForegroundColor DarkCyan; break }

        foreach ($r in $data) { $all.Add($r) | Out-Null }
        Start-Sleep -Milliseconds $SleepMs
    }

    $all | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($all.Count) block rows to: $Path" -ForegroundColor Green
}

# -------------------------
# Hydration (grouped by bowler with nested games)
# -------------------------
function Get-LaneTalkCompletedHydratedGrouped {
<#
.SYNOPSIS
    Fetches /completed/<page> and hydrates each bowler with nested game detail objects.

.DESCRIPTION
    Returns one object per bowler entry from /completed. Each object contains:
      - bowler fields
      - games: array of detailed game objects (trimmed)
#>
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$MaxGames = 5000,
        [int]$SleepMs = 25
    )

    $completed = Get-LaneTalkCompleted -Page $Page
    if (-not $completed) { return @() }

    $out = New-Object System.Collections.Generic.List[object]
    $count = 0

    foreach ($c in $completed) {
        $ids = @()
        if ($c.gameIds) { $ids = @($c.gameIds) }

        $games = New-Object System.Collections.Generic.List[object]

        foreach ($gid in $ids) {
            $count++
            if ($count -gt $MaxGames) {
                Write-Warning "MaxGames limit hit ($MaxGames). Stopping to avoid hammering the API."
                break
            }

            $g = Get-LaneTalkGameDetail -GameId ([long]$gid)

            # Keep it useful, not insane
            $games.Add([pscustomobject]@{
                id            = $g.id
                game          = $g.game
                lane          = $g.lane
                scoreType     = $g.scoreType
                competitionId = $g.competitionId
                playerId      = $g.playerId
                playerName    = $g.playerName
                teamName      = $g.teamName
                startTime     = $g.startTime
                endTime       = $g.endTime
                adjustedFrames = $g.adjustedFrames
                scores        = $g.scores
                throws        = $g.throws
                pins          = $g.pins
                speed         = $g.speed
                belongsTo     = $g.belongsTo
                claimedByCurrentUser = $g.claimedByCurrentUser
                folderId      = $g.folderId
                notes         = $g.notes
                tags          = $g.tags
            }) | Out-Null

            if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        }

        $out.Add([pscustomobject]@{
            blockId    = $c.blockId
            modified   = $c.modified
            playerName = $c.playerName
            teamName   = $c.teamName
            totalScore = $c.totalScore
            gameCount  = $games.Count
            games      = $games
        }) | Out-Null
    }

    return $out
}

function Show-LaneTalkCompletedHydratedGrouped {
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [int]$MaxGames = 5000,
        [int]$SleepMs = 25
    )

    $rows = Get-LaneTalkCompletedHydratedGrouped -Page $Page -MaxGames $MaxGames -SleepMs $SleepMs

    $rows |
        Sort-Object totalScore -Descending |
        Select-Object playerName, teamName, totalScore, gameCount, blockId |
        Format-Table -AutoSize

    if ($rows.Count -gt 0) {
        "`nFirst bowler games:`n"
        $rows[0].games |
            Select-Object id, game, lane, startTime, endTime, @{n="finalScore";e={ ($_.scores | Select-Object -Last 1) }} |
            Format-Table -AutoSize
    }
}

function Export-LaneTalkCompletedHydratedGroupedToCsv {
<#
.SYNOPSIS
    Exports one row per bowler with nested games stored as JSON in a single CSV column.
#>
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxGames = 5000,
        [int]$SleepMs = 25
    )

    $rows = Get-LaneTalkCompletedHydratedGrouped -Page $Page -MaxGames $MaxGames -SleepMs $SleepMs

    $flat = $rows | Select-Object `
        blockId, modified, playerName, teamName, totalScore, gameCount,
        @{n="gamesJson"; e={ ($_.games | ConvertTo-Json -Depth 50 -Compress) }}

    $flat | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($flat.Count) bowler rows to: $Path" -ForegroundColor Green
}

function Export-LaneTalkCompletedHydratedGroupedToJson {
<#
.SYNOPSIS
    Exports grouped hydrated results to a JSON file (recommended for nested data).
#>
    [CmdletBinding()]
    param(
        [int]$Page = 1,
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxGames = 5000,
        [int]$SleepMs = 25
    )

    $rows = Get-LaneTalkCompletedHydratedGrouped -Page $Page -MaxGames $MaxGames -SleepMs $SleepMs
    $rows | ConvertTo-Json -Depth 50 | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Exported $($rows.Count) bowler objects to: $Path" -ForegroundColor Green
}

# -------------------------
# Menu
# -------------------------
function Show-LaneTalkMenu {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "LaneTalk Menu" -ForegroundColor Cyan
    Write-Host ("CenterId: {0}" -f $script:LaneTalkCenterId) -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  1) One-shot scoreboard (Completed Page 1)"
    Write-Host "  2) Watch scoreboard (Completed Page 1, 5s poll)"
    Write-Host "  3) One-shot scoreboard (choose completed page)"
    Write-Host "  4) Watch scoreboard (choose completed page & poll seconds)"
    Write-Host "  5) Force refresh REST API key (debug)"
    Write-Host "  6) Export completed to CSV (prompt)"
    Write-Host "  7) Export completed to CSV (Page 1 -> ./lanetalk_completed_page_1.csv)"
    Write-Host "  8) Export ALL completed pages to one CSV (prompt)"
    Write-Host "  9) Export ALL completed pages (default ./lanetalk_completed_ALL.csv)"
    Write-Host " 10) Show blocks search RAW (Page 1, size 5)"
    Write-Host " 11) Export blocks search to CSV (prompt)"
    Write-Host " 12) Export ALL blocks search (default ./lanetalk_blocks_ALL.csv)"
    Write-Host " 13) Show game detail RAW (prompt for gameId)"
    Write-Host " 14) Show hydrated grouped by bowler (Completed Page 1)"
    Write-Host " 15) Export hydrated grouped by bowler to CSV (prompt)"
    Write-Host " 16) Export hydrated grouped by bowler to JSON (prompt, recommended)"
    Write-Host "  0) Exit"
    Write-Host ""
}

function Start-LaneTalkInteractive {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-LaneTalkMenu
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Show-LaneTalkCompletedScoreboardOnce -Page 1 }
            "2" { Watch-LaneTalkCompletedScoreboard -Page 1 -PollSeconds 5 }
            "3" {
                $p = Read-Host "Completed page number"
                $page = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                Show-LaneTalkCompletedScoreboardOnce -Page $page
            }
            "4" {
                $p = Read-Host "Completed page number"
                $s = Read-Host "Poll seconds (>=5 recommended)"
                $page = 0; $poll = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                if (-not [int]::TryParse($s, [ref]$poll)) { Write-Warning "Invalid poll seconds"; break }
                Watch-LaneTalkCompletedScoreboard -Page $page -PollSeconds $poll
            }
            "5" {
                $centerId = $script:LaneTalkCenterId
                $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId"
                $newKey = Get-LaneTalkLiveScoresApiKey -LiveScoresUrl $liveScoresUrl -ForceRefresh
                Write-Host "Refreshed REST apiKey (cached): $newKey" -ForegroundColor Green
            }
            "6" {
                $p = Read-Host "Completed page number"
                $page = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                $default = Join-Path $PWD ("lanetalk_completed_page_{0}.csv" -f $page)
                $path = Read-Host "CSV output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }
                Export-LaneTalkCompletedToCsv -Page $page -Path $path
            }
            "7" {
                $default = Join-Path $PWD "lanetalk_completed_page_1.csv"
                Export-LaneTalkCompletedToCsv -Page 1 -Path $default
            }
            "8" {
                $default = Join-Path $PWD "lanetalk_completed_ALL.csv"
                $path = Read-Host "CSV output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }
                Export-LaneTalkCompletedAllToCsv -Path $path -StartPage 1 -MaxPages 500
            }
            "9" {
                $default = Join-Path $PWD "lanetalk_completed_ALL.csv"
                Export-LaneTalkCompletedAllToCsv -Path $default -StartPage 1 -MaxPages 500
            }
            "10" { Show-LaneTalkFinishedBlocksRaw -Page 1 -PageSize 5 }
            "11" {
                $p = Read-Host "Blocks search page number"
                $ps = Read-Host "PageSize (Enter for 200)"
                $page = 0
                $pageSize = 200
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                if (-not [string]::IsNullOrWhiteSpace($ps)) { [void][int]::TryParse($ps, [ref]$pageSize) }
                $default = Join-Path $PWD ("lanetalk_blocks_page_{0}.csv" -f $page)
                $path = Read-Host "CSV output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }
                Export-LaneTalkFinishedBlocksToCsv -Page $page -PageSize $pageSize -Path $path
            }
            "12" {
                $default = Join-Path $PWD "lanetalk_blocks_ALL.csv"
                Export-LaneTalkFinishedBlocksAllToCsv -Path $default -StartPage 1 -PageSize 200 -MaxPages 500
            }
            "13" {
                $g = Read-Host "GameId"
                $gid = 0L
                if (-not [long]::TryParse($g, [ref]$gid)) { Write-Warning "Invalid GameId"; break }
                Show-LaneTalkGameDetailRaw -GameId $gid
            }
            "14" {
                Show-LaneTalkCompletedHydratedGrouped -Page 1 -MaxGames 5000 -SleepMs 25
            }
            "15" {
                $p = Read-Host "Completed page number"
                $page = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }

                $default = Join-Path $PWD ("lanetalk_completed_grouped_hydrated_page_{0}.csv" -f $page)
                $path = Read-Host "CSV output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }

                Export-LaneTalkCompletedHydratedGroupedToCsv -Page $page -Path $path -MaxGames 5000 -SleepMs 25
            }
            "16" {
                $p = Read-Host "Completed page number"
                $page = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }

                $default = Join-Path $PWD ("lanetalk_completed_grouped_hydrated_page_{0}.json" -f $page)
                $path = Read-Host "JSON output path (Enter for default: $default)"
                if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }

                Export-LaneTalkCompletedHydratedGroupedToJson -Page $page -Path $path -MaxGames 5000 -SleepMs 25
            }
            "0" { Write-Host "Later." -ForegroundColor Gray; return }
            default { Write-Warning "Unknown option: $choice" }
        }
    }
}

# -------------------------
# Auto-run
# -------------------------
Write-Host ""
Write-Host "LaneTalk helper loaded." -ForegroundColor Cyan
Write-Host ("CenterId: {0}" -f $script:LaneTalkCenterId) -ForegroundColor Cyan
Write-Host ""
Write-Host "Auto-starting interactive menu..." -ForegroundColor Yellow

Start-LaneTalkInteractive