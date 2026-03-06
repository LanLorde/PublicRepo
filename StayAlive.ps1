param(
  [switch]$UseAscii,
  [switch]$UseUnicode
)

Clear-Host

function Initialize-ConsoleEncoding {
  try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [Console]::OutputEncoding = $utf8NoBom
    [Console]::InputEncoding = $utf8NoBom
  } catch {
    Write-Verbose "Could not set console UTF-8 encoding in this host: $($_.Exception.Message)"
  }

  if ($PSVersionTable.PSEdition -eq 'Desktop') {
    try {
      chcp.com 65001 > $null
    } catch {
      Write-Verbose "Could not switch console code page to 65001: $($_.Exception.Message)"
    }
  }
}

Initialize-ConsoleEncoding
$isLegacyWindowsPowerShell = ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -lt 6)

$sceneAscii = @"
  ____________________        ________________________________________________
 / __________________/|       / ____________________________________________ /|
| |  DISK  DRIVE    | |      / /                                            / |
| | [====]  [__]    | |     / /____________________________________________/  |
| |________________| |    | |                                            |   |
|  ___  ___  ___     |    | |                                            |   |
| | o || o || o |    |    | |                                            |   |
| |___||___||___|    |    | |____________________________________________|   |
| /________________/| |   |  ____________________________________________    |
|/________________/ | |   | /__________________________________________/|    |
|  POWER   RESET     | |   |/__________________________________________/ |    |
                   | |          \_____________________________________/  /
                   | |           \__[__][__][__][__][__][__][__]__/  /
                   |_|            \____[__][__][__][__][__]_____/__/
"@

$sceneAsciiPressed = $sceneAscii -replace '\[__\]\[__\]\[__\]\[__\]\[__\]', '[__][__][__][##][__]'

function New-BirdAsciiFrame {
  param(
    [int]$Indent,
    [bool]$Bend,
    [bool]$PressKey
  )
  $b = ' ' * $Indent
  $scene = if ($PressKey) { $sceneAsciiPressed } else { $sceneAscii }

  # Bird is anchored by its body; head moves forward only in the "press" frame.
  $neckLen = 9
  if ($Bend) {
    $headIndent = $Indent + 16
  } else {
    $headIndent = $Indent + 6
  }

  $neckLines = @()
  for ($k = 0; $k -lt $neckLen; $k++) {
    if ($Bend) {
      # Head is to the right; neck slopes down-left (~45 deg) toward the body.
      $spaces = [Math]::Max($Indent + 4, $headIndent - $k)
      $neckLines += (' ' * $spaces) + '/'
    } else {
      $neckLines += (' ' * $headIndent) + '|'
    }
  }
  $neck = ($neckLines -join [Environment]::NewLine)
  $h = ' ' * $headIndent

  return @"
$scene
$h  __
$h (o )>
$neck
$b     .----.
$b     |____|
$b      /  \
$b     /____\
"@
}

$birdFramesAscii = @(
  (New-BirdAsciiFrame -Indent 0 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 2 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 4 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 6 -Bend:$true  -PressKey:$true),
  (New-BirdAsciiFrame -Indent 6 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 4 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 2 -Bend:$false -PressKey:$false),
  (New-BirdAsciiFrame -Indent 0 -Bend:$false -PressKey:$false)
)

$sceneUnicode = @"
  ┌────────────────────┐        ┌──────────────────────────────────────────┐
  │  DISK  DRIVE [ ]   │        │                                          │
  │  [====]  [__]      │        │                                          │
  │                  [ ]│        │                                          │
  └────────────────────┘        │                                          │
   ┌─o──┬─o──┬─o──┐              │                                          │
   │   │   │   │ │              ├──────────────────────────────────────────┤
   └───┴───┴───┘ │              │                                          │
     POWER  RESET│              │                                          │
                │              └──────────────────────────────────────────┘
                │                 \____________________________________/
                │                  \__[__][__][__][__][__][__][__][\_]__/
                └────────────────────\__[__][__][__][__][__][__]__/
"@

$sceneUnicodePressed = $sceneUnicode -replace '\[__\]\[__\]\[__\]\[__\]\[__\]\[__\]', '[__][__][__][__][##][__]'

function New-BirdUnicodeFrame {
  param(
    [int]$Indent,
    [bool]$Bend,
    [bool]$PressKey
  )
  $b = ' ' * $Indent
  $scene = if ($PressKey) { $sceneUnicodePressed } else { $sceneUnicode }

  $neckLen = 9
  if ($Bend) {
    $headIndent = $Indent + 16
  } else {
    $headIndent = $Indent + 6
  }

  $neckLines = @()
  for ($k = 0; $k -lt $neckLen; $k++) {
    if ($Bend) {
      $spaces = [Math]::Max($Indent + 4, $headIndent - $k)
      $neckLines += (' ' * $spaces) + '/'
    } else {
      $neckLines += (' ' * $headIndent) + '|'
    }
  }
  $neck = ($neckLines -join [Environment]::NewLine)
  $h = ' ' * $headIndent

  return @"
$scene
$h  __
$h (o )>
$neck
$b     .----.
$b     |____|
$b      /  \
$b     /____\
"@
}

$birdFramesUnicode = @(
  (New-BirdUnicodeFrame -Indent 0 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 2 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 4 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 6 -Bend:$true  -PressKey:$true),
  (New-BirdUnicodeFrame -Indent 6 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 4 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 2 -Bend:$false -PressKey:$false),
  (New-BirdUnicodeFrame -Indent 0 -Bend:$false -PressKey:$false)
)


$sendKeysAvailable = $false
try {
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  $sendKeysAvailable = $true
} catch {
  Write-Warning "System.Windows.Forms is unavailable; keep-awake keystroke sending is disabled."
}
$con=$host.UI.RawUI
$con.WindowTitle="Running Staying Alive, to kill close window or press CTRL + 'C'"

if ($UseUnicode -and $isLegacyWindowsPowerShell) {
  Write-Warning "Unicode mode is not reliable in Windows PowerShell 5.1. Falling back to ASCII."
}

$useUnicodeRuntime = ($UseUnicode -and -not $UseAscii -and -not $isLegacyWindowsPowerShell)
$birdFrames = if ($useUnicodeRuntime) { $birdFramesUnicode } else { $birdFramesAscii }
While ($true) {
  foreach ($frame in $birdFrames) {
    Clear-Host
    Write-Host $frame
    Start-Sleep -Milliseconds 250 -ErrorAction SilentlyContinue
  }
  Start-Sleep -Seconds 30 -ErrorAction SilentlyContinue
  if ($sendKeysAvailable) {
    try {
      [System.Windows.Forms.SendKeys]::SendWait("^")
    } catch {
      Write-Verbose "SendKeys failed in this host: $($_.Exception.Message)"
    }
  }
}
