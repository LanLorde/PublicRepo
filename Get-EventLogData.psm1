
function Get-EventLogData {
    <#
    .SYNOPSIS
    Retrieves Windows Event Log entries based on log name, event IDs, and time range.

    .PARAMETER LogName
    The name of the event log. Supports dynamic tab-completion from available logs.

    .PARAMETER EventIds
    One or more event IDs to filter (e.g., 1014, 55, 4201).

    .PARAMETER HoursBack
    How many hours back to search from the current time.

    .EXAMPLE
    Get-EventLogData -LogName System -EventIds 1014,4201 -HoursBack 12

    .EXAMPLE
    Get-EventLogData -LogName Microsoft-Windows-TerminalServices-LocalSessionManager/Operational -EventIds 24 -HoursBack 6
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            Get-WinEvent -ListLog * | Where-Object { $_.LogName -like "$wordToComplete*" } | ForEach-Object { $_.LogName }
        })]
        [string]$LogName,

        [int[]]$EventIds = @(1014, 55, 4201),

        [int]$HoursBack = 6
    )

    $StartTime = (Get-Date).AddHours(-$HoursBack)

    Get-WinEvent -FilterHashtable @{
        LogName   = $LogName
        Id        = $EventIds
        StartTime = $StartTime
    } | Select-Object TimeCreated, Id, Message
}

# Example usage:
Get-EventLogData -LogName System -EventIds 1014,4201 -HoursBack 12
