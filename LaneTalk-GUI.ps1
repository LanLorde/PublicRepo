<#
.SYNOPSIS
    WinForms GUI wrapper for LaneTalk.ps1 (bowler search + game picker + scoreboard viewer).

.DESCRIPTION
    - Dot-sources LaneTalk.ps1 so all your existing API/functions stay untouched.
    - Provides a simple GUI to search players, pick games, and view scoreboards.
    - "More Games" mimics the console behavior: show more from current set, then scan further back.

.NOTES
    Run with:
      powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\LaneTalk-GUI.ps1
#>

# ----------------------------
# Path to your existing script
# ----------------------------
$LaneTalkPath = Join-Path $PSScriptRoot 'LaneTalk.ps1'
if (-not (Test-Path $LaneTalkPath)) {
    throw "Can't find LaneTalk.ps1 at: $LaneTalkPath"
}

. $LaneTalkPath

# ----------------------------
# WinForms setup
# ----------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function New-Label([string]$text, [int]$x, [int]$y, [int]$w = 80, [int]$h = 20) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    return $l
}

function Set-UiBusy {
    param(
        [bool]$Busy,
        [string]$Status = $null
    )
    $global:btnSearch.Enabled     = -not $Busy
    $global:btnListAll.Enabled    = -not $Busy
    $global:btnLoadGames.Enabled  = -not $Busy
    $global:btnMoreGames.Enabled  = -not $Busy
    $global:btnShowAll.Enabled    = -not $Busy

    $global:txtSearch.Enabled     = -not $Busy
    $global:dtpSince.Enabled      = -not $Busy
    $global:chkUseSince.Enabled   = -not $Busy

    $global:lstPlayers.Enabled    = -not $Busy
    $global:lvGames.Enabled       = -not $Busy

    if ($Status) { $global:lblStatus.Text = $Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# ----------------------------
# State
# ----------------------------
$script:SearchPagesDefault = 5
$script:MaxPagesCap        = 60

$script:CurrentPlayers = @()
$script:CurrentPlayer  = $null

$script:GamesPagesBase     = 5   # initial pages to scan
$script:GamesPagesCurrent  = 5   # expands as you hit "More Games"
$script:AllGameIds         = @()
$script:ListCount          = 0
$script:ChunkSize          = 20  # like MaxListGames

# ----------------------------
# UI layout
# ----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "LaneTalk GUI"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.MinimumSize = New-Object System.Drawing.Size(1000, 700)

# Top panel
$panelTop = New-Object System.Windows.Forms.Panel
$panelTop.Dock = 'Top'
$panelTop.Height = 80

$panelTop.Controls.Add((New-Label "Bowler:" 10 12 60 20))
$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(70, 10)
$txtSearch.Size = New-Object System.Drawing.Size(260, 22)
$panelTop.Controls.Add($txtSearch)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Text = "Search"
$btnSearch.Location = New-Object System.Drawing.Point(340, 8)
$btnSearch.Size = New-Object System.Drawing.Size(90, 26)
$panelTop.Controls.Add($btnSearch)

$btnListAll = New-Object System.Windows.Forms.Button
$btnListAll.Text = "List All (?)"
$btnListAll.Location = New-Object System.Drawing.Point(440, 8)
$btnListAll.Size = New-Object System.Drawing.Size(95, 26)
$panelTop.Controls.Add($btnListAll)

$chkUseSince = New-Object System.Windows.Forms.CheckBox
$chkUseSince.Text = "Since date"
$chkUseSince.Location = New-Object System.Drawing.Point(70, 40)
$chkUseSince.Size = New-Object System.Drawing.Size(90, 22)
$panelTop.Controls.Add($chkUseSince)

$dtpSince = New-Object System.Windows.Forms.DateTimePicker
$dtpSince.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
$dtpSince.Location = New-Object System.Drawing.Point(165, 40)
$dtpSince.Size = New-Object System.Drawing.Size(110, 22)
$dtpSince.Enabled = $false
$panelTop.Controls.Add($dtpSince)

$chkUseSince.add_CheckedChanged({
    $dtpSince.Enabled = $chkUseSince.Checked
})

$btnLoadGames = New-Object System.Windows.Forms.Button
$btnLoadGames.Text = "Load Games"
$btnLoadGames.Location = New-Object System.Drawing.Point(550, 8)
$btnLoadGames.Size = New-Object System.Drawing.Size(110, 26)
$panelTop.Controls.Add($btnLoadGames)

$btnMoreGames = New-Object System.Windows.Forms.Button
$btnMoreGames.Text = "More Games"
$btnMoreGames.Location = New-Object System.Drawing.Point(670, 8)
$btnMoreGames.Size = New-Object System.Drawing.Size(110, 26)
$panelTop.Controls.Add($btnMoreGames)

$btnShowAll = New-Object System.Windows.Forms.Button
$btnShowAll.Text = "Show All Scoreboards"
$btnShowAll.Location = New-Object System.Drawing.Point(790, 8)
$btnShowAll.Size = New-Object System.Drawing.Size(170, 26)
$panelTop.Controls.Add($btnShowAll)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready."
$lblStatus.AutoEllipsis = $true
$lblStatus.Location = New-Object System.Drawing.Point(550, 42)
$lblStatus.Size = New-Object System.Drawing.Size(600, 22)
$panelTop.Controls.Add($lblStatus)

# Main split: left players, right games+scoreboard
$splitMain = New-Object System.Windows.Forms.SplitContainer
$splitMain.Dock = 'Fill'
$splitMain.Orientation = 'Vertical'
$splitMain.SplitterDistance = 320

# Left: players
$grpPlayers = New-Object System.Windows.Forms.GroupBox
$grpPlayers.Text = "Players"
$grpPlayers.Dock = 'Fill'

$lstPlayers = New-Object System.Windows.Forms.ListBox
$lstPlayers.Dock = 'Fill'
$lstPlayers.IntegralHeight = $false
$grpPlayers.Controls.Add($lstPlayers)
$splitMain.Panel1.Controls.Add($grpPlayers)

# Right: games on top, scoreboard bottom
$splitRight = New-Object System.Windows.Forms.SplitContainer
$splitRight.Dock = 'Fill'
$splitRight.Orientation = 'Horizontal'
$splitRight.SplitterDistance = 260

$grpGames = New-Object System.Windows.Forms.GroupBox
$grpGames.Text = "Games"
$grpGames.Dock = 'Fill'

$lvGames = New-Object System.Windows.Forms.ListView
$lvGames.Dock = 'Fill'
$lvGames.View = 'Details'
$lvGames.FullRowSelect = $true
$lvGames.HideSelection = $false
$lvGames.MultiSelect = $false
$lvGames.Columns.Add("When", 110) | Out-Null
$lvGames.Columns.Add("Game", 55)  | Out-Null
$lvGames.Columns.Add("Lane", 55)  | Out-Null
$lvGames.Columns.Add("Score", 70) | Out-Null
$lvGames.Columns.Add("GameId", 120) | Out-Null
$grpGames.Controls.Add($lvGames)
$splitRight.Panel1.Controls.Add($grpGames)

$grpScore = New-Object System.Windows.Forms.GroupBox
$grpScore.Text = "Scoreboard"
$grpScore.Dock = 'Fill'

$txtScore = New-Object System.Windows.Forms.TextBox
$txtScore.Dock = 'Fill'
$txtScore.Multiline = $true
$txtScore.ScrollBars = 'Both'
$txtScore.WordWrap = $false
$txtScore.ReadOnly = $true
$txtScore.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpScore.Controls.Add($txtScore)
$splitRight.Panel2.Controls.Add($grpScore)

$splitMain.Panel2.Controls.Add($splitRight)

$form.Controls.Add($splitMain)
$form.Controls.Add($panelTop)

# Globals used by Set-UiBusy
$global:btnSearch    = $btnSearch
$global:btnListAll   = $btnListAll
$global:btnLoadGames = $btnLoadGames
$global:btnMoreGames = $btnMoreGames
$global:btnShowAll   = $btnShowAll
$global:txtSearch    = $txtSearch
$global:dtpSince     = $dtpSince
$global:chkUseSince  = $chkUseSince
$global:lstPlayers   = $lstPlayers
$global:lvGames      = $lvGames
$global:lblStatus    = $lblStatus

# ----------------------------
# Helpers
# ----------------------------
function Clear-GamesUi {
    $lvGames.Items.Clear()
    $txtScore.Clear()
    $script:AllGameIds = @()
    $script:ListCount = 0
}

function Populate-Players([string[]]$players) {
    $lstPlayers.BeginUpdate()
    try {
        $lstPlayers.Items.Clear()
        foreach ($p in $players) { [void]$lstPlayers.Items.Add($p) }
    } finally {
        $lstPlayers.EndUpdate()
    }
}

function Add-GameItem {
    param(
        [object]$GameRaw
    )

    $whenLocal = $null
    if ($GameRaw.startTime) {
        $whenLocal = Convert-FromUnixTime -UnixSeconds ([long]$GameRaw.startTime)
    }

    $finalScore = $null
    if ($GameRaw.scores) { $finalScore = ($GameRaw.scores | Select-Object -Last 1) }
    if ($null -eq $finalScore) { $finalScore = $GameRaw.score }

    $whenText = if ($whenLocal) { (Get-Date $whenLocal -Format 'MM/dd HH:mm') } else { "" }

    $item = New-Object System.Windows.Forms.ListViewItem($whenText)
    [void]$item.SubItems.Add(("G{0}" -f $GameRaw.game))
    [void]$item.SubItems.Add([string]$GameRaw.lane)
    [void]$item.SubItems.Add([string]$finalScore)
    [void]$item.SubItems.Add([string]$GameRaw.id)

    # stash raw object
    $item.Tag = $GameRaw
    [void]$lvGames.Items.Add($item)
}

function Load-GamesForCurrentPlayer {
    param(
        [switch]$ExpandIfNeeded
    )

    if (-not $script:CurrentPlayer) { return }

    Set-UiBusy -Busy $true -Status "Loading games for '$($script:CurrentPlayer)'..."

    try {
        if (-not $ExpandIfNeeded) {
            $script:GamesPagesCurrent = $script:GamesPagesBase
            $script:AllGameIds = @(Get-LaneTalkPlayerGameIds -PlayerName $script:CurrentPlayer -MaxPages $script:GamesPagesCurrent)
            $script:AllGameIds = @($script:AllGameIds | Select-Object -Unique)
            $script:ListCount = [Math]::Min($script:ChunkSize, $script:AllGameIds.Count)
        } else {
            # mimic your console: first show more already-known, then scan further back
            if ($script:ListCount -lt $script:AllGameIds.Count) {
                $script:ListCount = [Math]::Min($script:AllGameIds.Count, $script:ListCount + $script:ChunkSize)
            } else {
                $prevCount = $script:AllGameIds.Count
                $script:GamesPagesCurrent += [Math]::Max(1, $script:GamesPagesBase)
                if ($script:GamesPagesCurrent -gt 200) { $script:GamesPagesCurrent = 200 }

                $moreIds = @(Get-LaneTalkPlayerGameIds -PlayerName $script:CurrentPlayer -MaxPages $script:GamesPagesCurrent)
                $moreIds = @($moreIds | Select-Object -Unique)

                if ($moreIds.Count -gt 0) { $script:AllGameIds = $moreIds }

                if ($script:AllGameIds.Count -le $prevCount) {
                    $lblStatus.Text = "No more games found in older pages (scanned $($script:GamesPagesCurrent) pages)."
                } else {
                    $script:ListCount = [Math]::Min($script:AllGameIds.Count, $script:ListCount + $script:ChunkSize)
                }
            }
        }

        $lvGames.BeginUpdate()
        try {
            $lvGames.Items.Clear()

            if (-not $script:AllGameIds -or $script:AllGameIds.Count -eq 0) {
                $lblStatus.Text = "No games found for '$($script:CurrentPlayer)'."
                return
            }

            $idsToShow = @()
            if ($script:ListCount -gt 0) {
                $maxIdx = [Math]::Min($script:ListCount, $script:AllGameIds.Count) - 1
                $idsToShow = @($script:AllGameIds[0..$maxIdx])
            }

            $loaded = 0
            foreach ($gid in $idsToShow) {
                try {
                    $g = Get-LaneTalkGameDetail -GameId ([long]$gid)
                    Add-GameItem -GameRaw $g
                    $loaded++
                } catch {
                    # skip failures
                }
            }

            $lblStatus.Text = "Loaded $loaded game(s). Showing $($lvGames.Items.Count)/$($script:AllGameIds.Count). Pages scanned: $($script:GamesPagesCurrent)."
        } finally {
            $lvGames.EndUpdate()
        }
    } catch {
        $lblStatus.Text = "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.ToString(), "LaneTalk GUI Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        Set-UiBusy -Busy $false
    }
}

function Show-SelectedGameScoreboard {
    if (-not $lvGames.SelectedItems -or $lvGames.SelectedItems.Count -eq 0) { return }
    $raw = $lvGames.SelectedItems[0].Tag
    if (-not $raw) { return }

    $whenLocal = $null
    if ($raw.startTime) { $whenLocal = Convert-FromUnixTime -UnixSeconds ([long]$raw.startTime) }

    $finalScore = $null
    if ($raw.scores) { $finalScore = ($raw.scores | Select-Object -Last 1) }
    if ($null -eq $finalScore) { $finalScore = $raw.score }

    $header = @()
    $header += "LaneTalk - Game Scoreboard"
    $header += ("Player: {0}" -f $raw.playerName)
    if ($raw.teamName) { $header += ("Team:   {0}" -f $raw.teamName) }
    $header += ("GameId: {0} (G{1} Lane {2})" -f $raw.id, $raw.game, $raw.lane)
    if ($whenLocal) { $header += ("When:   {0:MM/dd/yyyy HH:mm}" -f $whenLocal) }
    if ($null -ne $finalScore) { $header += ("Score:  {0}" -f $finalScore) }
    $header += ""

    $txtScore.Text = ($header -join "`r`n") + (Format-LaneTalkScoreboard -Game $raw)
}

# ----------------------------
# Events
# ----------------------------
$btnSearch.Add_Click({
    $q = $txtSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($q)) { return }

    Set-UiBusy -Busy $true -Status "Searching players..."
    try {
        $pages = $script:SearchPagesDefault

        if ($chkUseSince.Checked) {
            # Expand pages to reach date (same concept as name@YYYY-MM-DD)
            $since = $dtpSince.Value.Date
            $pages = Resolve-LaneTalkPagesForDate -Since $since -MaxPages $script:MaxPagesCap -SampleRowsPerPage 3 -SleepMs 25
            if ($pages -gt $script:MaxPagesCap) { $pages = $script:MaxPagesCap }
        }

        $players = @(Find-LaneTalkPlayers -Query $q -MaxPages $pages)
        $script:CurrentPlayers = $players
        Populate-Players -players $players

        Clear-GamesUi
        $script:CurrentPlayer = $null

        $lblStatus.Text = "Found $($players.Count) player(s) (pages scanned: $pages)."
    } catch {
        $lblStatus.Text = "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.ToString(), "Search Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        Set-UiBusy -Busy $false
    }
})

$btnListAll.Add_Click({
    $txtSearch.Text = "?"
    $btnSearch.PerformClick()
})

$lstPlayers.Add_SelectedIndexChanged({
    if ($lstPlayers.SelectedItem) {
        $script:CurrentPlayer = [string]$lstPlayers.SelectedItem
        Clear-GamesUi
        $lblStatus.Text = "Selected player: $($script:CurrentPlayer). Click 'Load Games'."
    }
})

$btnLoadGames.Add_Click({
    if (-not $script:CurrentPlayer) {
        if ($lstPlayers.SelectedItem) { $script:CurrentPlayer = [string]$lstPlayers.SelectedItem }
    }
    if (-not $script:CurrentPlayer) { return }

    # base pages depends on search pages / since-date selection
    $script:GamesPagesBase = $script:SearchPagesDefault
    if ($chkUseSince.Checked) {
        $since = $dtpSince.Value.Date
        $p = Resolve-LaneTalkPagesForDate -Since $since -MaxPages $script:MaxPagesCap -SampleRowsPerPage 3 -SleepMs 25
        if ($p -gt $script:MaxPagesCap) { $p = $script:MaxPagesCap }
        $script:GamesPagesBase = $p
    }

    Load-GamesForCurrentPlayer
})

$btnMoreGames.Add_Click({
    if (-not $script:CurrentPlayer) { return }
    if (-not $script:AllGameIds -or $script:AllGameIds.Count -eq 0) {
        Load-GamesForCurrentPlayer
        return
    }
    Load-GamesForCurrentPlayer -ExpandIfNeeded
})

$lvGames.Add_DoubleClick({
    Show-SelectedGameScoreboard
})

$lvGames.Add_SelectedIndexChanged({
    # single-click preview
    Show-SelectedGameScoreboard
})

$btnShowAll.Add_Click({
    if ($lvGames.Items.Count -eq 0) { return }

    Set-UiBusy -Busy $true -Status "Rendering all loaded scoreboards..."
    try {
        $sb = New-Object System.Text.StringBuilder
        $i = 0

        foreach ($item in $lvGames.Items) {
            $i++
            $raw = $item.Tag
            if (-not $raw) { continue }

            [void]$sb.AppendLine(("==== {0}/{1} ====" -f $i, $lvGames.Items.Count))
            [void]$sb.AppendLine(("Player: {0}" -f $raw.playerName))
            [void]$sb.AppendLine(("GameId: {0} (G{1} Lane {2})" -f $raw.id, $raw.game, $raw.lane))
            [void]$sb.AppendLine((Format-LaneTalkScoreboard -Game $raw))
            [void]$sb.AppendLine("")
        }

        $txtScore.Text = $sb.ToString()
        $lblStatus.Text = "Rendered $($lvGames.Items.Count) scoreboard(s)."
    } catch {
        $lblStatus.Text = "Error: $($_.Exception.Message)"
    } finally {
        Set-UiBusy -Busy $false
    }
})

# Press Enter in search box triggers Search
$txtSearch.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') {
        $_.SuppressKeyPress = $true
        $btnSearch.PerformClick()
    }
})

# ----------------------------
# Launch
# ----------------------------
try {
    $center = $null
    try { $center = Get-LaneTalkCenterStatus -CacheSeconds 300 -Quiet } catch { $center = $null }
    if ($center) {
        $name = $center.companyName
        if (-not $name) { $name = $center.name }
        if ($name) { $form.Text = "LaneTalk GUI - $name" }
    }
} catch { }

[void]$form.ShowDialog()
