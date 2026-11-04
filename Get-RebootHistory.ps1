#requires -Version 5.1
function Get-RebootHistory {
    <#
    .SYNOPSIS
        Gets reboot summaries or an event timeline for local or remote Windows computers.
    .DESCRIPTION
        Reads provider-filtered System events with Get-WinEvent. Each computer gets its
        own summary, including computers with no retained events or a failed query.
        Startup and unexpected-shutdown signals are correlated to avoid counting
        several records from the same boot as several reboots.

        Default output keeps the original summary names. Dates are UTC DateTime values.
        PercentDirty is now a numeric percentage (0 through 100 for complete history);
        PercentDirtyDisplay supplies the old formatted text. LastShutdown describes
        a shutdown/restart REQUEST (User32 1074), not proof it completed.

        UnexpectedShutdowns contains detection/startup times. Windows may record an
        unexpected shutdown only at the next boot. Detailed output preserves the
        original, localized failure date/time separately as ReportedShutdownTime.
        Counts describe retained events, not an exhaustive lifetime history.
    .PARAMETER ComputerName
        One or more computer names, also accepted from the pipeline. Defaults to local.
    .PARAMETER Credential
        Alternate credentials for remote event-log queries. Omitted for local aliases.
    .PARAMETER StartTime
        Optional beginning of the event-record window. Default: all retained history.
    .PARAMETER EndTime
        End of the event-record window. Default: the time the command is called.
    .PARAMETER RecentDays
        Days ending at EndTime used by RecentShutdowns and RecentUnexpected. Default 30.
    .PARAMETER Detailed
        Returns flat event rows suitable for CSV, with correlated IncidentId values.
        A QueryStatus row represents an empty or failed query.
    .EXAMPLE
        . .\Get-RebootHistory.ps1
        Get-RebootHistory -ComputerName server01,server02
    .EXAMPLE
        Get-RebootHistory server01 -Credential (Get-Credential) |
            Where-Object { $_.Status -eq 'Success' -and $_.PercentDirty -ge 30 }
    .EXAMPLE
        Get-RebootHistory -StartTime (Get-Date).AddDays(-90) -Detailed |
            Export-Csv .\reboot-events.csv -NoTypeInformation
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .NOTES
        Original author: Eric Westfall, eawestfall@gmail.com
        Original version: 1.1, November 26, 2014
        Version 2.0: Spot/BK-Spot fork, November 4, 2026.
        Requires Windows PowerShell 5.1 or PowerShell 7 on Windows. Remote access uses
        Windows Event Log RPC, not WinRM. See docs/Get-RebootHistory.md for semantics.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('CN', 'Computer')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Position = 1)]
        [Alias('Cred')]
        [ValidateNotNull()]
        [pscredential]$Credential = [pscredential]::Empty,

        [datetime]$StartTime,
        [datetime]$EndTime = [datetime]::UtcNow,
        [ValidateRange(1, 36500)]
        [int]$RecentDays = 30,
        [switch]$Detailed
    )
    begin {
        if ($env:OS -ne 'Windows_NT') { throw 'Get-RebootHistory requires Windows event logs.' }
        $endUtc = $EndTime.ToUniversalTime()
        $hasStart = $PSBoundParameters.ContainsKey('StartTime')
        if ($hasStart -and $StartTime.ToUniversalTime() -gt $endUtc) {
            throw 'StartTime must be earlier than or equal to EndTime.'
        }
        $recentCutoff = $endUtc.AddDays(-$RecentDays)
        $localNames = @('.', 'localhost', '127.0.0.1', '::1', $env:COMPUTERNAME)
        $domain = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
        if ($domain) { $localNames += ($env:COMPUTERNAME + '.' + $domain) }
        $timePredicate = "TimeCreated[@SystemTime &lt;= '$($endUtc.ToString('o'))']"
        if ($hasStart) {
            $timePredicate += " and TimeCreated[@SystemTime &gt;= '$($StartTime.ToUniversalTime().ToString('o'))']"
        }
        # Pair event IDs with their providers; IDs alone are not globally unique.
        $providerFilters = @(
            "Provider[@Name='Microsoft-Windows-Kernel-General'] and (EventID=12 or EventID=13)",
            "Provider[@Name='EventLog'] and (EventID=6005 or EventID=6006 or EventID=6008 or EventID=6009)",
            "(Provider[@Name='User32'] or Provider[@Name='USER32']) and EventID=1074",
            "Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=41",
            "Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting'] and EventID=1001"
        )
        $selects = foreach ($filter in $providerFilters) {
            '<Select Path="System">*[System[(' + $filter + ') and ' + $timePredicate + ']]</Select>'
        }
        $query = '<QueryList><Query Id="0" Path="System">' + ($selects -join '') + '</Query></QueryList>'
    }
    process {
        foreach ($computer in $ComputerName) {
            # All mutable history belongs to this computer, including pipeline calls.
            $rows = [Collections.Generic.List[object]]::new()
            $warnings = [Collections.Generic.List[string]]::new()
            $status = 'Success'
            $queryError = $null
            $parameters = @{ FilterXml = $query; ErrorAction = 'Stop' }
            if ($localNames -notcontains $computer) {
                $parameters.ComputerName = $computer
                if ($Credential -ne [pscredential]::Empty) { $parameters.Credential = $Credential }
            }
            try {
                $events = @(Get-WinEvent @parameters)
            } catch {
                $events = @()
                if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                    $status = 'Error'
                    $queryError = $_.Exception.Message
                    Write-Warning ('Unable to retrieve reboot history for {0}: {1}' -f $computer, $queryError)
                }
            }
            foreach ($event in $events) {
                # Also validate provider/ID on returned data, including imported fixtures.
                $type = $null
                switch ($event.ProviderName) {
                    'Microsoft-Windows-Kernel-General' {
                        if ($event.Id -eq 12) { $type = 'Boot' }
                        if ($event.Id -eq 13) { $type = 'ShutdownStarted' }
                    }
                    'EventLog' {
                        switch ($event.Id) {
                            6005 { $type = 'EventLogStarted' }
                            6006 { $type = 'EventLogStopped' }
                            6008 { $type = 'UnexpectedShutdownDetected' }
                            6009 { $type = 'BootVersion' }
                        }
                    }
                    'User32' { if ($event.Id -eq 1074) { $type = 'ShutdownRequested' } }
                    'Microsoft-Windows-Kernel-Power' { if ($event.Id -eq 41) { $type = 'UnexpectedShutdownDetected' } }
                    'Microsoft-Windows-WER-SystemErrorReporting' { if ($event.Id -eq 1001) { $type = 'Bugcheck' } }
                }
                if (-not $type) { continue }
                if ($null -eq $event.TimeCreated) {
                    $warnings.Add(('Event {0} has no creation time and was excluded.' -f $event.RecordId))
                    continue
                }
                $when = $event.TimeCreated.ToUniversalTime()
                if ($when -gt $endUtc -or ($hasStart -and $when -lt $StartTime.ToUniversalTime())) { continue }
                $values = @{}
                $orderedValues = [Collections.Generic.List[string]]::new()
                $payloadError = $null
                try {
                    [xml]$xml = $event.ToXml()
                    $ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
                    $ns.AddNamespace('e', 'http://schemas.microsoft.com/win/2004/08/events/event')
                    foreach ($node in $xml.SelectNodes('/e:Event/e:EventData/e:Data', $ns)) {
                        if ($node.HasAttribute('Name')) { $values[$node.GetAttribute('Name')] = $node.InnerText }
                        $orderedValues.Add($node.InnerText)
                    }
                } catch {
                    $payloadError = $_.Exception.Message
                    $warnings.Add(('Event {0} payload could not be read: {1}' -f $event.RecordId, $_.Exception.Message))
                }
                $reported = $null
                if ($event.Id -eq 6008 -and $orderedValues.Count -ge 2) {
                    # Preserve remote localized text; do not guess its culture/time zone.
                    $reported = ($orderedValues[1] + ' ' + $orderedValues[0]) -replace '[\p{Cf}]', ''
                }
                $rows.Add([pscustomobject][ordered]@{
                    Computer = $computer; TimeCreated = $when; EventId = [int]$event.Id
                    Provider = $event.ProviderName; RecordId = $event.RecordId; Type = $type
                    IncidentId = $null; IncidentTime = $null; User = $null; Process = $null
                    ShutdownType = $null; ReasonCode = $null; Reason = $null; Comment = $null
                    ReportedShutdownTime = $reported; BugcheckCode = $null
                    Status = $(if ($payloadError) { 'Partial' } else { 'Success' }); Error = $payloadError
                })
                $row = $rows[$rows.Count - 1]
                if ($event.Id -eq 1074) {
                    $row.Process = $values['param1']; $row.Reason = $values['param3']
                    $row.ReasonCode = $values['param4']; $row.ShutdownType = $values['param5']
                    $row.Comment = $values['param6']; $row.User = $values['param7']
                }
                if ($event.Id -eq 41) { $row.BugcheckCode = $values['BugcheckCode'] }
                if ($event.Id -eq 1001) { $row.BugcheckCode = $values['param1'] }
            }
            $sorted = @($rows | Sort-Object TimeCreated, RecordId)
            $boots = [Collections.Generic.List[object]]::new()
            foreach ($row in @($sorted | Where-Object { $_.EventId -eq 12 })) { $boots.Add($row) }
            foreach ($row in @($sorted | Where-Object { $_.EventId -eq 6009 })) {
                $nearBoot = @($boots | Where-Object { $_.EventId -eq 12 -and [Math]::Abs(($_.TimeCreated - $row.TimeCreated).TotalSeconds) -le 300 })
                if (-not $nearBoot.Count) { $boots.Add($row) }
            }
            $bootsOrdered = @($boots | Sort-Object TimeCreated)
            $incidents = [Collections.Generic.List[object]]::new()
            foreach ($row in @($sorted | Where-Object { $_.Type -in @('UnexpectedShutdownDetected', 'Bugcheck') })) {
                $nearBoots = @($bootsOrdered | Where-Object {
                    [Math]::Abs(($_.TimeCreated - $row.TimeCreated).TotalSeconds) -le 300
                })
                $boot = $nearBoots | Where-Object { $_.RecordId -le $row.RecordId } |
                    Sort-Object RecordId -Descending | Select-Object -First 1
                if (-not $boot) {
                    $boot = $nearBoots | Sort-Object @{
                        Expression = { [Math]::Abs(($_.TimeCreated - $row.TimeCreated).TotalSeconds) }
                    } | Select-Object -First 1
                }
                $incident = $null
                if ($boot) {
                    $incident = $incidents | Where-Object { $_.BootRecordId -eq $boot.RecordId } | Select-Object -First 1
                } else {
                    # With no boot marker, combine different signal IDs only. Two 6008
                    # records remain separate even when their timestamps are close.
                    $incident = $incidents | Where-Object {
                        $null -eq $_.BootRecordId -and
                        [Math]::Abs(($_.Time - $row.TimeCreated).TotalSeconds) -le 300 -and
                        $_.EventIds -notcontains $row.EventId
                    } | Select-Object -Last 1
                }
                if (-not $incident) {
                    $incident = [pscustomobject]@{
                        Id = ('{0}:unexpected:{1}' -f $computer, $row.RecordId)
                        Time = $(if ($boot) { $boot.TimeCreated } else { $row.TimeCreated })
                        BootRecordId = $(if ($boot) { $boot.RecordId } else { $null })
                        EventIds = @()
                    }
                    $incidents.Add($incident)
                }
                $incident.EventIds = @($incident.EventIds) + @($row.EventId)
                $row.IncidentId = $incident.Id; $row.IncidentTime = $incident.Time
            }
            $bootTimes = @($bootsOrdered | ForEach-Object { $_.TimeCreated })
            $unexpectedTimes = @($incidents | Sort-Object Time | ForEach-Object { $_.Time })
            $last = $sorted | Where-Object { $_.Type -eq 'ShutdownRequested' } | Sort-Object TimeCreated, RecordId -Descending | Select-Object -First 1
            $percent = $null
            if ($bootTimes.Count) { $percent = [Math]::Round(100.0 * $unexpectedTimes.Count / $bootTimes.Count, 2) }
            if ($unexpectedTimes.Count -gt $bootTimes.Count) { $warnings.Add('Unexpected incidents exceed retained boot markers; percentage may be unavailable or exceed 100.') }
            if ($status -eq 'Success' -and -not $sorted.Count) { $status = 'NoEvents' }
            if ($status -eq 'Success' -and $warnings.Count) { $status = 'Partial' }
            if ($Detailed) {
                if ($sorted.Count) {
                    $sorted | Sort-Object TimeCreated, RecordId -Descending
                    foreach ($message in $warnings) { Write-Warning ('{0}: {1}' -f $computer, $message) }
                } else {
                    [pscustomobject][ordered]@{
                        Computer=$computer; TimeCreated=$null; EventId=$null; Provider=$null; RecordId=$null
                        Type='QueryStatus'; IncidentId=$null; IncidentTime=$null; User=$null; Process=$null
                        ShutdownType=$null; ReasonCode=$null; Reason=$null; Comment=$null
                        ReportedShutdownTime=$null; BugcheckCode=$null; Status=$status; Error=$queryError
                    }
                }
            } else {
                [pscustomobject][ordered]@{
                    Computer = $computer
                    BootHistory = $bootTimes
                    RecentShutdowns = $(if ($status -eq 'Error') { $null } else { @($bootTimes | Where-Object { $_ -ge $recentCutoff }).Count })
                    UnexpectedShutdowns = $unexpectedTimes
                    RecentUnexpected = $(if ($status -eq 'Error') { $null } else { @($unexpectedTimes | Where-Object { $_ -ge $recentCutoff }).Count })
                    PercentDirty = $percent
                    LastShutdown = $(if ($last) { $last.TimeCreated } else { $null })
                    LastShutdownType = $(if ($last) { $last.ShutdownType } else { $null })
                    LastShutdownUser = $(if ($last) { $last.User } else { $null })
                    LastShutdownProcess = $(if ($last) { $last.Process } else { $null })
                    LastShutdownReason = $(if ($last) { 'Reason Code: {0}, Reason: {1}' -f $last.ReasonCode, $last.Reason } else { $null })
                    BootCount = $(if ($status -eq 'Error') { $null } else { $bootTimes.Count })
                    UnexpectedCount = $(if ($status -eq 'Error') { $null } else { $unexpectedTimes.Count })
                    PercentDirtyDisplay = $(if ($null -ne $percent) { '{0:0.##}%' -f $percent } else { $null })
                    LastBoot = $(if ($bootTimes.Count) { $bootTimes[-1] } else { $null })
                    RecentDays = $RecentDays
                    QueryStartTime = $(if ($hasStart) { $StartTime.ToUniversalTime() } else { $null })
                    QueryEndTime = $endUtc
                    Status = $status
                    Error = $queryError
                    HistoryWarnings = @($warnings.ToArray())
                }
            }
        }
    }
}
