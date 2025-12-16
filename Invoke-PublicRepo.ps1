
function Invoke-PublicRepoScript {
<#
.SYNOPSIS
    Fetches a script from LanLorde/PublicRepo main branch and executes it inline.

.EXAMPLE
    Invoke-PublicRepoScript -Name Setup.ps1
.EXAMPLE
    ipr Setup.ps1
#>
    [CmdletBinding()]
    [Alias('ipr','iprs')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $url = "https://raw.githubusercontent.com/LanLorde/PublicRepo/refs/heads/main/$Name"

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
        Invoke-Expression $response.Content
    }
    catch {
        Write-Host "Could not find $Name, check the spelling and its availability in the public repo" -ForegroundColor Cyan
    }
}
