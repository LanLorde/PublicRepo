
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

    .PARAMETER Export
    Switch to enable exporting the results.

    .PARAMETER ExportPath
    The file path where the results will be exported. Required if -Export is specified.

    .PARAMETER ExportFormat
    The export format: CSV, JSON, or XML. Default is CSV.

    .EXAMPLE
    Get-EventLogData -LogName System -EventIds 1014,4201 -HoursBack 12

    .EXAMPLE
    Get-EventLogData -LogName System -EventIds 1014,4201 -HoursBack 6 -Export -ExportPath "C:\Logs\events.csv"

    .EXAMPLE
    Get-EventLogData -LogName Microsoft-Windows-TerminalServices-LocalSessionManager/Operational -EventIds 24 -HoursBack 6 -Export -ExportPath "C:\Logs\events.json" -ExportFormat JSON
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

        [int]$HoursBack = 6,

        [switch]$Export,

        [string]$ExportPath,

        [ValidateSet('CSV', 'JSON', 'XML')]
        [string]$ExportFormat = 'CSV'
    )

    $StartTime = (Get-Date).AddHours(-$HoursBack)

    $events = Get-WinEvent -FilterHashtable @{
        LogName   = $LogName
        Id        = $EventIds
        StartTime = $StartTime
    } | Select-Object TimeCreated, Id, Message

    if ($Export) {
        if ([string]::IsNullOrWhiteSpace($ExportPath)) {
            Write-Error "ExportPath is required when using the Export switch."
            return
        }

        # Create directory if it doesn't exist
        $directory = Split-Path -Path $ExportPath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        # Export based on format
        switch ($ExportFormat) {
            'CSV' {
                $events | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                Write-Verbose "Events exported to CSV: $ExportPath"
            }
            'JSON' {
                $events | ConvertTo-Json -Depth 3 | Out-File -Path $ExportPath -Force
                Write-Verbose "Events exported to JSON: $ExportPath"
            }
            'XML' {
                $events | Export-Clixml -Path $ExportPath -Force
                Write-Verbose "Events exported to XML: $ExportPath"
            }
        }

        Write-Host "Export completed successfully: $ExportPath" -ForegroundColor Green
    }

    return $events
}

