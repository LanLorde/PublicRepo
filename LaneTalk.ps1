# =========================
# LaneTalk LiveScores Helper
# Key extraction + caching + auto refresh on 401/403
# CenterId hardcoded (per request)
# Auto-launch interactive menu on script run
# Includes: Export page, Export all pages (until empty)
# =========================

# ---- HARD-CODED CENTER ID (only thing hardcoded) ----
$script:LaneTalkCenterId = [Guid]"eb0f0b49-b676-430a-9a69-86bf9638b6b1"

function Get-LaneTalkCachePath {
    [CmdletBinding()]
    param(
        [string]$Name = "lanetalk_apikey.json"
    )

    $dir = Join-Path $env:LOCALAPPDATA "LaneTalk"
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    Join-Path $dir $Name
}

function Read-LaneTalkApiKeyCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CachePath
    )

    if (-not (Test-Path $CachePath)) { return $null }

    try {
        $raw = Get-Content -Path $CachePath -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        return $obj
    } catch {
        return $null
    }
}

function Write-LaneTalkApiKeyCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CachePath,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $obj = [pscustomobject]@{
        apiKey      = $ApiKey
        cachedAt    = (Get-Date).ToString("o")
        cachedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    }

    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $CachePath -Encoding UTF8
}

function Get-LaneTalkJsAssetUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LiveScoresUrl
    )

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    $base = [Uri]$LiveScoresUrl
    $origin = "{0}://{1}" -f $base.Scheme, $base.Host

    $htmlResp = Invoke-WebRequest -Uri $LiveScoresUrl -Headers @{
        "User-Agent" = $ua
        "Accept"     = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    } -Method GET -MaximumRedirection 5 -TimeoutSec 30

    $html = $htmlResp.Content
    if (-not $html) { throw "LiveScores HTML was empty." }

    # Pull all /assets/*.js references
    $matches = [regex]::Matches($html, '(?<path>/assets/[^"''\s>]+\.js)', 'IgnoreCase')
    if ($matches.Count -lt 1) { throw "Could not find any /assets/*.js references in the LiveScores HTML." }

    # Build absolute URLs + dedupe
    $urls = $matches |
        ForEach-Object { "$origin$($_.Groups['path'].Value)" } |
        Select-Object -Unique

    return $urls
}

function Extract-LaneTalkApiKeyFromJs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JsContent
    )

    # Patterns that survive minification changes reasonably well
    $patterns = @(
        'headers\.apiKey\s*=\s*"(?<k>[^"]+)"',
        'headers\.apikey\s*=\s*"(?<k>[^"]+)"',
        '["'']apiKey["'']\s*:\s*["''](?<k>[^"''\s]+)["'']',
        '["'']apikey["'']\s*:\s*["''](?<k>[^"''\s]+)["'']',
        '\bapiKey\b.{0,120}?["''](?<k>[A-Za-z0-9]{20,80})["'']'
    )

    foreach ($pat in $patterns) {
        $m = [regex]::Match($JsContent, $pat, 'IgnoreCase')
        if ($m.Success -and $m.Groups['k'].Value) {
            return $m.Groups['k'].Value
        }
    }

    return $null
}

function Get-LaneTalkLiveScoresApiKey {
<#
.SYNOPSIS
    Gets the LaneTalk LiveScores frontend API key with caching and resilient extraction.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LiveScoresUrl,

        [int]$CacheTtlHours = 168,

        [switch]$ForceRefresh
    )

    $cachePath = Get-LaneTalkCachePath
    $cached = Read-LaneTalkApiKeyCache -CachePath $cachePath

    if (-not $ForceRefresh -and $cached -and $cached.apiKey) {
        try {
            $cachedAt = [datetime]::Parse($cached.cachedAt)
            if ((Get-Date) -lt $cachedAt.AddHours($CacheTtlHours)) {
                return $cached.apiKey
            }
        } catch {}
    }

    $assetUrls = Get-LaneTalkJsAssetUrls -LiveScoresUrl $LiveScoresUrl

    $ordered = @(
        $assetUrls | Where-Object { $_ -match '/assets/index' }
        $assetUrls | Where-Object { $_ -notmatch '/assets/index' }
    ) | Select-Object -Unique

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    foreach ($jsUrl in $ordered) {
        try {
            $jsResp = Invoke-WebRequest -Uri $jsUrl -Headers @{
                "User-Agent" = $ua
                "Accept"     = "application/javascript,text/javascript,*/*;q=0.8"
                "Referer"    = "https://livescores.lanetalk.com/"
            } -Method GET -TimeoutSec 30

            $key = Extract-LaneTalkApiKeyFromJs -JsContent $jsResp.Content
            if ($key) {
                Write-LaneTalkApiKeyCache -CachePath $cachePath -ApiKey $key
                return $key
            }
        } catch { continue }
    }

    throw "Failed to extract LaneTalk API key from any JS asset. Frontend structure may have changed."
}

function Invoke-LaneTalkApi {
<#
.SYNOPSIS
    Calls a LaneTalk API endpoint using an auto-extracted API key.
    If 401/403, force refresh key once and retry.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$LiveScoresUrl,

        [string]$Method = "GET",

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
            return Invoke-RestMethod -Method $m -Uri $u -Headers $h -Body ($b | ConvertTo-Json -Depth 10) -ContentType "application/json" -TimeoutSec 30
        } else {
            return Invoke-RestMethod -Method $m -Uri $u -Headers $h -TimeoutSec 30
        }
    }

    try {
        return & $invoke $Uri $Method $headers $Body
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

function Format-LaneTalkGameScores {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $GameScores
    )
    process {
        if ($null -eq $GameScores) { return "" }
        if ($GameScores -is [System.Collections.IEnumerable] -and -not ($GameScores -is [string])) {
            return ($GameScores | ForEach-Object { "$_" }) -join ","
        }
        return "$GameScores"
    }
}

function Get-LaneTalkCompleted {
    [CmdletBinding()]
    param(
        [int]$Page = 1
    )

    $centerId = $script:LaneTalkCenterId
    $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId?tab=finished&q=&order=date&sort=asc"
    $uri = "https://api.lanetalk.com/v1/bowlingcenters/$centerId/completed/$Page"

    Invoke-LaneTalkApi -Uri $uri -LiveScoresUrl $liveScoresUrl -Method GET
}

function Show-LaneTalkCompletedScoreboardOnce {
    [CmdletBinding()]
    param(
        [int]$Page = 1
    )

    $data = Get-LaneTalkCompleted -Page $Page

    $data |
        Sort-Object totalScore -Descending |
        Select-Object playerName, totalScore,
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
                Select-Object playerName, totalScore, teamName,
                    @{n="gameScores"; e={ Format-LaneTalkGameScores $_.gameScores }} |
                Format-Table -AutoSize
        }

        Start-Sleep -Seconds $PollSeconds
    }
}

function Convert-LaneTalkCompletedToExportRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Data
    )

    $Data | Select-Object `
        playerName,
        teamName,
        totalScore,
        @{n="gameScores"; e={ Format-LaneTalkGameScores $_.gameScores }},
        @{n="gameIds"; e={ if ($_.gameIds -is [System.Collections.IEnumerable] -and -not ($_.gameIds -is [string])) { ($_.gameIds -join ",") } else { "$($_.gameIds)" } }},
        modified,
        blockId
}

function Export-LaneTalkCompletedToCsv {
    [CmdletBinding()]
    param(
        [int]$Page = 1,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $data = Get-LaneTalkCompleted -Page $Page
    $out  = Convert-LaneTalkCompletedToExportRows -Data $data

    $out | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($out.Count) rows to: $Path" -ForegroundColor Green
}

function Export-LaneTalkCompletedToCsvPrompt {
    [CmdletBinding()]
    param()

    $p = Read-Host "Page number"
    $page = 0
    if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; return }

    $defaultPath = Join-Path $PWD ("lanetalk_completed_page_{0}.csv" -f $page)
    $path = Read-Host "CSV output path (Enter for default: $defaultPath)"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $defaultPath }

    Export-LaneTalkCompletedToCsv -Page $page -Path $path
}

function Export-LaneTalkCompletedAllToCsv {
<#
.SYNOPSIS
    Exports ALL completed pages to a single CSV by paging /completed/<n> until an empty array is returned.

.PARAMETER Path
    Output CSV path.

.PARAMETER StartPage
    Start page number (default 1).

.PARAMETER MaxPages
    Safety cap to avoid infinite loops if the API misbehaves.

.PARAMETER SleepMs
    Small delay between page fetches to be polite / avoid rate limits.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$StartPage = 1,

        [int]$MaxPages = 500,

        [int]$SleepMs = 200
    )

    $all = New-Object System.Collections.Generic.List[object]

    for ($page = $StartPage; $page -le $MaxPages; $page++) {
        Write-Host "Fetching page $page..." -ForegroundColor DarkCyan

        $data = $null
        try {
            $data = Get-LaneTalkCompleted -Page $page
        } catch {
            throw "Failed fetching page $page $($_.Exception.Message)"
        }

        # If empty/null -> done
        if ($null -eq $data -or ($data.PSObject.TypeNames -contains 'System.Object[]' -and $data.Count -eq 0) -or ($data -is [System.Collections.IEnumerable] -and -not ($data -is [string]) -and ($data | Measure-Object).Count -eq 0)) {
            Write-Host "No results on page $page. Stopping." -ForegroundColor DarkCyan
            break
        }

        $rows = Convert-LaneTalkCompletedToExportRows -Data $data
        foreach ($r in $rows) { $all.Add($r) }

        Start-Sleep -Milliseconds $SleepMs
    }

    $all | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $Path
    Write-Host "Exported $($all.Count) rows to: $Path" -ForegroundColor Green
}

function Export-LaneTalkCompletedAllToCsvPrompt {
    [CmdletBinding()]
    param()

    $defaultPath = Join-Path $PWD "lanetalk_completed_ALL.csv"
    $path = Read-Host "CSV output path (Enter for default: $defaultPath)"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $defaultPath }

    $sp = Read-Host "Start page (Enter for 1)"
    $startPage = 1
    if (-not [string]::IsNullOrWhiteSpace($sp)) {
        if (-not [int]::TryParse($sp, [ref]$startPage)) { Write-Warning "Invalid start page; using 1."; $startPage = 1 }
    }

    $mp = Read-Host "Max pages safety cap (Enter for 500)"
    $maxPages = 500
    if (-not [string]::IsNullOrWhiteSpace($mp)) {
        if (-not [int]::TryParse($mp, [ref]$maxPages)) { Write-Warning "Invalid max pages; using 500."; $maxPages = 500 }
    }

    Export-LaneTalkCompletedAllToCsv -Path $path -StartPage $startPage -MaxPages $maxPages
}

function Show-LaneTalkMenu {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "LaneTalk Menu" -ForegroundColor Cyan
    Write-Host ("CenterId: {0}" -f $script:LaneTalkCenterId) -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  1) One-shot scoreboard (Page 1)"
    Write-Host "  2) Watch scoreboard (Page 1, 5s poll)"
    Write-Host "  3) One-shot scoreboard (choose page)"
    Write-Host "  4) Watch scoreboard (choose page & poll seconds)"
    Write-Host "  5) Force refresh API key (debug)"
    Write-Host "  6) Export to CSV (prompt for page & path)"
    Write-Host "  7) Export to CSV (Page 1 -> ./lanetalk_completed_page_1.csv)"
    Write-Host "  8) Export ALL pages to one CSV (prompt)"
    Write-Host "  9) Export ALL pages (default ./lanetalk_completed_ALL.csv)"
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
                $p = Read-Host "Page number"
                $page = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                Show-LaneTalkCompletedScoreboardOnce -Page $page
            }
            "4" {
                $p = Read-Host "Page number"
                $s = Read-Host "Poll seconds (>=5 recommended)"
                $page = 0
                $poll = 0
                if (-not [int]::TryParse($p, [ref]$page)) { Write-Warning "Invalid page number"; break }
                if (-not [int]::TryParse($s, [ref]$poll)) { Write-Warning "Invalid poll seconds"; break }
                Watch-LaneTalkCompletedScoreboard -Page $page -PollSeconds $poll
            }
            "5" {
                $centerId = $script:LaneTalkCenterId
                $liveScoresUrl = "https://livescores.lanetalk.com/livescoring/$centerId?tab=finished&q=&order=date&sort=asc"
                $newKey = Get-LaneTalkLiveScoresApiKey -LiveScoresUrl $liveScoresUrl -ForceRefresh
                Write-Host "Refreshed apiKey (cached): $newKey" -ForegroundColor Green
            }
            "6" { Export-LaneTalkCompletedToCsvPrompt }
            "7" {
                $default = Join-Path $PWD "lanetalk_completed_page_1.csv"
                Export-LaneTalkCompletedToCsv -Page 1 -Path $default
            }
            "8" { Export-LaneTalkCompletedAllToCsvPrompt }
            "9" {
                $default = Join-Path $PWD "lanetalk_completed_ALL.csv"
                Export-LaneTalkCompletedAllToCsv -Path $default
            }
            "0" { Write-Host "Later." -ForegroundColor Gray; return }
            default { Write-Warning "Unknown option: $choice" }
        }
    }
}

# =========================
# On-run output + auto-launch menu
# =========================
Write-Host ""
Write-Host "LaneTalk helper loaded." -ForegroundColor Cyan
Write-Host ("CenterId: {0}" -f $script:LaneTalkCenterId) -ForegroundColor Cyan
Write-Host ""
Write-Host "Auto-starting interactive menu..." -ForegroundColor Yellow

Start-LaneTalkInteractive